import Foundation
import SwiftData
import os

/// Actor-isolated job orchestration system for managing ingestion tasks
actor IngestionOrchestrator {
    static let shared = IngestionOrchestrator()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "IngestionOrchestrator")
    
    // Job management
    private var activeJobs: [UUID: IngestionJob] = [:]
    private var jobQueue: PriorityQueue<IngestionJob> = PriorityQueue()
    private var completedJobs: [UUID: IngestionJob] = [:]
    
    // Concurrency control
    private var runningJobCount = 0
    private var maxConcurrentJobs = 3
    private var cancellationTokens: [UUID: CancellationToken] = [:]
    
    // Circuit breakers for plugins
    private var circuitBreakers: [String: CircuitBreaker] = [:]
    
    private init() {}
    
    // MARK: - Job Scheduling
    
    func scheduleJob(_ spec: JobSpec, for source: ContextSource) async throws -> UUID {
        let job = IngestionJob(
            id: spec.id,
            sourceId: spec.sourceId,
            pluginId: spec.pluginId,
            spec: spec,
            source: source
        )
        
        activeJobs[job.id] = job
        jobQueue.enqueue(job)
        
        logger.info("Scheduled job \(job.id) for plugin \(spec.pluginId)")
        
        // Start processing if capacity available
        await tryStartNextJob()
        
        return job.id
    }
    
    func scheduleJobs(_ specs: [JobSpec], for source: ContextSource) async throws -> [UUID] {
        var jobIds: [UUID] = []
        
        for spec in specs {
            let jobId = try await scheduleJob(spec, for: source)
            jobIds.append(jobId)
        }
        
        return jobIds
    }
    
    func cancelJob(_ jobId: UUID) async {
        if let job = activeJobs[jobId] {
            job.status = .cancelled
            
            // Cancel plugin execution if running
            if let token = cancellationTokens[jobId] {
                token.cancel()
                cancellationTokens.removeValue(forKey: jobId)
            }
            
            activeJobs.removeValue(forKey: jobId)
            logger.info("Cancelled job \(jobId)")
        }
    }
    
    func cancelAllJobs(for sourceId: UUID) async {
        let sourceJobs = activeJobs.values.filter { $0.sourceId == sourceId }
        
        for job in sourceJobs {
            await cancelJob(job.id)
        }
        
        logger.info("Cancelled \(sourceJobs.count) jobs for source \(sourceId)")
    }
    
    // MARK: - Job Execution
    
    private func tryStartNextJob() async {
        guard runningJobCount < maxConcurrentJobs,
              let job = jobQueue.dequeue() else {
            return
        }
        
        // Check circuit breaker
        let circuitBreaker = getCircuitBreaker(for: job.pluginId)
        guard circuitBreaker.canExecute() else {
            logger.warning("Circuit breaker open for plugin \(job.pluginId), delaying job")
            
            // Re-queue with delay
            Task.detached { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                await self?.enqueueJobWithDelay(job)
            }
            return
        }
        
        runningJobCount += 1
        job.status = .running
        job.startedAt = Date()
        
        logger.info("Starting job \(job.id) for plugin \(job.pluginId)")
        
        Task.detached { [weak self] in
            await self?.executeJob(job)
        }
    }
    
    private func executeJob(_ job: IngestionJob) async {
        let cancellationToken = CancellationToken()
        cancellationTokens[job.id] = cancellationToken
        
        do {
            // Get plugin
            guard let plugin = await PluginRegistry.shared.getPlugin(job.pluginId) else {
                throw IngestionError.pluginNotFound(job.pluginId)
            }
            
            // Check if plugin is available
            let isAvailable = await plugin.isAvailable()
            guard isAvailable else {
                throw IngestionError.pluginUnavailable(job.pluginId)
            }
            
            // Execute with timeout
            let artifacts = try await withThrowingTaskGroup(of: [any ContentArtifact].self) { group in
                group.addTask {
                    try await plugin.executeJob(job.spec)
                }
                
                // Timeout task
                group.addTask {
                    try await Task.sleep(for: .seconds(job.spec.timeout))
                    throw IngestionError.timeout(job.spec.timeout)
                }
                
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            
            // Success
            job.artifacts = artifacts
            job.status = .completed
            job.completedAt = Date()
            
            // Update circuit breaker
            let circuitBreaker = getCircuitBreaker(for: job.pluginId)
            circuitBreaker.recordSuccess()
            
            logger.info("Completed job \(job.id), produced \(artifacts.count) artifacts")
            
        } catch {
            // Handle failure
            job.status = .failed
            job.errorMessage = error.localizedDescription
            job.completedAt = Date()
            
            // Update circuit breaker
            let circuitBreaker = getCircuitBreaker(for: job.pluginId)
            circuitBreaker.recordFailure()
            
            // Check if retryable
            if shouldRetry(job, error: error) {
                await scheduleRetry(job)
            }
            
            logger.error("Job \(job.id) failed: \(error.localizedDescription)")
        }
        
        // Cleanup
        cancellationTokens.removeValue(forKey: job.id)
        activeJobs.removeValue(forKey: job.id)
        completedJobs[job.id] = job
        runningJobCount -= 1
        
        // Try to start next job
        await tryStartNextJob()
    }
    
    // MARK: - Helper Methods
    
    private func enqueueJobWithDelay(_ job: IngestionJob) async {
        jobQueue.enqueue(job)
        await tryStartNextJob()
    }
    
    private func shouldRetry(_ job: IngestionJob, error: Error) -> Bool {
        guard job.retryCount < job.spec.retryPolicy.maxRetries else {
            return false
        }
        
        // Check if error is retryable
        let errorType = determineErrorType(error)
        return job.spec.retryPolicy.retryableErrors.contains(errorType)
    }
    
    private func scheduleRetry(_ job: IngestionJob) async {
        job.retryCount += 1
        job.status = .pending
        
        // Calculate backoff delay
        let delay = calculateBackoffDelay(
            attempt: job.retryCount,
            strategy: job.spec.retryPolicy.backoffStrategy
        )
        
        logger.info("Scheduling retry \(job.retryCount) for job \(job.id) with delay \(delay)s")
        
        Task.detached { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await self?.enqueueJobWithDelay(job)
        }
    }
    
    private func calculateBackoffDelay(attempt: Int, strategy: BackoffStrategy) -> Double {
        switch strategy {
        case .linear:
            return Double(attempt) * 5.0 // 5s, 10s, 15s
        case .exponential:
            return pow(2.0, Double(attempt)) // 2s, 4s, 8s
        case .fixed:
            return 10.0 // Fixed 10s delay
        }
    }
    
    private func determineErrorType(_ error: Error) -> String {
        if error is URLError {
            return "network"
        } else if error.localizedDescription.contains("timeout") {
            return "timeout"
        } else if error.localizedDescription.contains("rate limit") {
            return "rate_limit"
        } else {
            return "generic"
        }
    }
    
    // MARK: - Circuit Breaker Management
    
    private func getCircuitBreaker(for pluginId: String) -> CircuitBreaker {
        if let existing = circuitBreakers[pluginId] {
            return existing
        }
        
        let circuitBreaker = CircuitBreaker(
            name: pluginId,
            failureThreshold: 5,
            timeout: 60.0
        )
        circuitBreakers[pluginId] = circuitBreaker
        return circuitBreaker
    }
    
    // MARK: - Job Status and Queries
    
    func getJobStatus(_ jobId: UUID) -> IngestionJobStatus? {
        if let job = activeJobs[jobId] {
            return job.status
        }
        if let job = completedJobs[jobId] {
            return job.status
        }
        return nil
    }
    
    func getJob(_ jobId: UUID) -> IngestionJob? {
        return activeJobs[jobId] ?? completedJobs[jobId]
    }
    
    func getActiveJobs() -> [IngestionJob] {
        return Array(activeJobs.values)
    }
    
    func getJobsForSource(_ sourceId: UUID) -> [IngestionJob] {
        let active = activeJobs.values.filter { $0.sourceId == sourceId }
        let completed = completedJobs.values.filter { $0.sourceId == sourceId }
        return Array(active) + Array(completed)
    }
    
    func getJobQueue() -> [IngestionJob] {
        return jobQueue.getAllElements()
    }
    
    // MARK: - Configuration
    
    func updateConfiguration(maxConcurrentJobs: Int) {
        self.maxConcurrentJobs = maxConcurrentJobs
        logger.info("Updated max concurrent jobs to \(maxConcurrentJobs)")
    }
    
    func cleanupCompletedJobs(olderThan: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-olderThan)
        let jobsToRemove = completedJobs.filter { _, job in
            guard let completedAt = job.completedAt else { return false }
            return completedAt < cutoffDate
        }
        
        for (jobId, _) in jobsToRemove {
            completedJobs.removeValue(forKey: jobId)
        }
        
        logger.info("Cleaned up \(jobsToRemove.count) completed jobs")
    }
}

// MARK: - Supporting Types

public final class IngestionJob: Identifiable, ObservableObject {
    public let id: UUID
    public let sourceId: UUID
    public let pluginId: String
    public let spec: JobSpec
    public let source: ContextSource
    
    @Published public var status: IngestionJobStatus = .pending
    public var artifacts: [any ContentArtifact] = []
    public var errorMessage: String?
    public var retryCount: Int = 0
    
    public var startedAt: Date?
    public var completedAt: Date?
    public let createdAt: Date = Date()
    
    public init(id: UUID, sourceId: UUID, pluginId: String, spec: JobSpec, source: ContextSource) {
        self.id = id
        self.sourceId = sourceId
        self.pluginId = pluginId
        self.spec = spec
        self.source = source
    }
    
    public var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
}

public enum IngestionJobStatus: String, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var isActive: Bool {
        return self == .pending || self == .running
    }
    
    public var isTerminal: Bool {
        return self == .completed || self == .failed || self == .cancelled
    }
}

// MARK: - Priority Queue

struct PriorityQueue<T> {
    private var elements: [T] = []
    private let comparator: (T, T) -> Bool
    
    init(comparator: @escaping (T, T) -> Bool = { _, _ in false }) {
        self.comparator = comparator
    }
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    var count: Int {
        return elements.count
    }
    
    mutating func enqueue(_ element: T) {
        elements.append(element)
        elements.sort(by: comparator)
    }
    
    mutating func dequeue() -> T? {
        return isEmpty ? nil : elements.removeFirst()
    }
    
    func peek() -> T? {
        return elements.first
    }
    
    func getAllElements() -> [T] {
        return elements
    }
}

extension PriorityQueue where T == IngestionJob {
    init() {
        self.init { job1, job2 in
            // Sort by priority, then by creation time
            if job1.spec.priority.sortOrder != job2.spec.priority.sortOrder {
                return job1.spec.priority.sortOrder < job2.spec.priority.sortOrder
            }
            return job1.createdAt < job2.createdAt
        }
    }
}

// MARK: - Circuit Breaker

final class CircuitBreaker {
    private let name: String
    private let failureThreshold: Int
    private let timeout: TimeInterval
    
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var state: CircuitBreakerState = .closed
    
    init(name: String, failureThreshold: Int, timeout: TimeInterval) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.timeout = timeout
    }
    
    func canExecute() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }
    
    func recordSuccess() {
        failureCount = 0
        state = .closed
    }
    
    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
    
    enum CircuitBreakerState {
        case closed
        case open
        case halfOpen
    }
}

// MARK: - Cancellation Token

final class CancellationToken {
    private var isCancelled = false
    
    func cancel() {
        isCancelled = true
    }
    
    var cancelled: Bool {
        return isCancelled
    }
}

// MARK: - Errors

enum IngestionError: LocalizedError {
    case pluginNotFound(String)
    case pluginUnavailable(String)
    case timeout(TimeInterval)
    case configurationInvalid(String)
    case jobNotFound(UUID)
    case maxConcurrencyReached
    
    var errorDescription: String? {
        switch self {
        case .pluginNotFound(let pluginId):
            return "Plugin '\(pluginId)' not found"
        case .pluginUnavailable(let pluginId):
            return "Plugin '\(pluginId)' is not available"
        case .timeout(let duration):
            return "Job timed out after \(duration) seconds"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        case .jobNotFound(let jobId):
            return "Job '\(jobId)' not found"
        case .maxConcurrencyReached:
            return "Maximum concurrency limit reached"
        }
    }
}