import Foundation
import SwiftData
import os

/// MCP-based URL crawler plugin using crawl4ai-mcp-server for web scraping
actor MCPCrawlerPlugin: SourcePlugin {
    typealias Config = MCPCrawlerConfiguration
    typealias Artifact = WebArtifact
    
    let pluginId = "com.sadiuysal.voiceink.plugins.mcpcrawler"
    let displayName = "MCP Web Crawler"
    let version = "1.0.0"
    let capabilities = PluginCapabilities(
        supportsOffline: false,
        requiresNetwork: true,
        requiresCredentials: false,
        maxConcurrentJobs: 2,
        supportedFormats: [.html, .markdown, .text, .json],
        supportedArtifactTypes: [.webPage, .document, .snippet, .metadata]
    )
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "MCPCrawlerPlugin")
    
    // Plugin state
    private var currentConfig: MCPCrawlerConfiguration?
    private var isConfigured = false
    private var runningJobs: [UUID: Task<[WebArtifact], Error>] = [:]
    
    // MCP integration
    private let mcpClient = MCPClient()
    
    init() {
        logger.info("MCP Crawler plugin initialized")
    }
    
    // MARK: - Plugin Lifecycle
    
    func configure(_ config: MCPCrawlerConfiguration) async throws {
        guard try await validate(config) else {
            throw MCPCrawlerError.invalidConfiguration("Configuration validation failed")
        }
        
        // Test MCP server availability
        guard await testMCPConnection() else {
            throw MCPCrawlerError.mcpUnavailable
        }
        
        currentConfig = config
        isConfigured = true
        
        logger.info("Configured MCP crawler plugin with \(config.rootUrls.count) root URLs")
    }
    
    func validate(_ config: MCPCrawlerConfiguration) async throws -> Bool {
        // Validate URLs
        for urlString in config.rootUrls {
            guard let url = URL(string: urlString), url.scheme != nil else {
                return false
            }
        }
        
        // Validate limits
        guard config.maxDepth > 0 && config.maxPages > 0 else {
            return false
        }
        
        return true
    }
    
    func isAvailable() async -> Bool {
        return await testMCPConnection()
    }
    
    // MARK: - Job Planning and Execution
    
    func planJobs(for source: ContextSource) async throws -> [JobSpec] {
        guard let config = currentConfig else {
            throw MCPCrawlerError.notConfigured
        }
        
        var jobSpecs: [JobSpec] = []
        
        // Create one job per root URL to enable parallel crawling
        for (index, rootUrl) in config.rootUrls.enumerated() {
            let jobSpec = JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: index == 0 ? .high : .normal, // First URL gets priority
                parameters: [
                    "root_url": rootUrl,
                    "max_depth": String(config.maxDepth),
                    "max_pages": String(config.maxPages / config.rootUrls.count), // Distribute pages
                    "include_patterns": config.includePatterns.joined(separator: ","),
                    "exclude_patterns": config.excludePatterns.joined(separator: ","),
                    "extract_content": String(config.extractContent),
                    "follow_links": String(config.followLinks),
                    "rate_limit_delay": String(config.rateLimitDelay)
                ],
                timeout: TimeInterval(config.timeoutSeconds)
            )
            
            jobSpecs.append(jobSpec)
        }
        
        // Add metadata collection job
        let metadataJob = JobSpec(
            sourceId: source.id,
            pluginId: pluginId,
            priority: .low,
            parameters: [
                "job_type": "metadata_collection",
                "root_urls": config.rootUrls.joined(separator: ",")
            ],
            dependencies: jobSpecs.map { $0.id }, // Wait for crawling jobs
            timeout: 60
        )
        jobSpecs.append(metadataJob)
        
        logger.info("Planned \(jobSpecs.count) crawling jobs")
        return jobSpecs
    }
    
    func executeJob(_ job: JobSpec) async throws -> [WebArtifact] {
        guard let config = currentConfig else {
            throw MCPCrawlerError.notConfigured
        }
        
        let jobType = job.parameters["job_type"] ?? "crawl"
        
        // Create cancellable task
        let task = Task<[WebArtifact], Error> {
            try await self.executeJobInternal(job: job, config: config, jobType: jobType)
        }
        
        runningJobs[job.id] = task
        
        do {
            let artifacts = try await task.value
            runningJobs.removeValue(forKey: job.id)
            
            logger.info("Completed job \(job.id) (\(jobType)), produced \(artifacts.count) artifacts")
            return artifacts
        } catch {
            runningJobs.removeValue(forKey: job.id)
            throw error
        }
    }
    
    private func executeJobInternal(
        job: JobSpec,
        config: MCPCrawlerConfiguration,
        jobType: String
    ) async throws -> [WebArtifact] {
        switch jobType {
        case "metadata_collection":
            return try await executeMetadataCollectionJob(job: job, config: config)
        default:
            return try await executeCrawlJob(job: job, config: config)
        }
    }
    
    func cancelJob(_ jobId: UUID) async {
        if let task = runningJobs[jobId] {
            task.cancel()
            runningJobs.removeValue(forKey: jobId)
            logger.info("Cancelled job: \(jobId)")
        }
    }
    
    func cleanup() async {
        // Cancel all running jobs
        for (_, task) in runningJobs {
            task.cancel()
        }
        runningJobs.removeAll()
        
        // Disconnect MCP client
        await mcpClient.disconnect()
        
        isConfigured = false
        currentConfig = nil
        
        logger.info("MCP crawler plugin cleaned up")
    }
    
    // MARK: - Content Preview and Testing
    
    func previewContent(for source: ContextSource) async throws -> ContentPreview {
        guard let config = currentConfig else {
            throw MCPCrawlerError.notConfigured
        }
        
        var sampleItems: [ContentPreview.PreviewItem] = []
        var totalEstimatedSize = 0
        var totalEstimatedPages = 0
        
        // Sample each root URL for preview
        for rootUrl in config.rootUrls.prefix(3) { // Limit to first 3 URLs
            do {
                let preview = try await previewUrl(rootUrl, config: config)
                sampleItems.append(ContentPreview.PreviewItem(
                    title: preview.title ?? URL(string: rootUrl)?.host ?? rootUrl,
                    type: .webPage,
                    size: preview.estimatedSize,
                    preview: preview.description
                ))
                
                totalEstimatedSize += preview.estimatedSize
                totalEstimatedPages += preview.estimatedPages
                
            } catch {
                logger.warning("Failed to preview URL \(rootUrl): \(error.localizedDescription)")
                
                sampleItems.append(ContentPreview.PreviewItem(
                    title: URL(string: rootUrl)?.host ?? rootUrl,
                    type: .webPage,
                    size: 0,
                    preview: "Preview unavailable: \(error.localizedDescription)"
                ))
            }
        }
        
        return ContentPreview(
            title: "Web Crawler Preview",
            description: "Crawling \(config.rootUrls.count) root URLs with max depth \(config.maxDepth)",
            itemCount: totalEstimatedPages,
            estimatedSize: totalEstimatedSize,
            sampleItems: sampleItems
        )
    }
    
    func testConnection(for source: ContextSource) async throws -> ConnectionTestResult {
        let startTime = Date()
        
        do {
            // Test MCP connection
            guard await testMCPConnection() else {
                return .failure(message: "MCP server is not available")
            }
            
            // Test URL accessibility if configured
            if let config = currentConfig, !config.rootUrls.isEmpty {
                let testUrl = config.rootUrls[0]
                let urlAccessible = try await testUrlAccessibility(testUrl)
                
                if !urlAccessible {
                    return .failure(
                        message: "Test URL is not accessible: \(testUrl)",
                        metadata: ["test_url": testUrl]
                    )
                }
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            return .success(
                message: "MCP server accessible and URLs reachable",
                latency: latency,
                metadata: [
                    "mcp_version": await mcpClient.getVersion(),
                    "capabilities": "crawl4ai-integration"
                ]
            )
            
        } catch {
            return .failure(
                message: "Connection test failed: \(error.localizedDescription)",
                metadata: ["error": error.localizedDescription]
            )
        }
    }
    
    // MARK: - Job Implementations
    
    private func executeCrawlJob(
        job: JobSpec,
        config: MCPCrawlerConfiguration
    ) async throws -> [WebArtifact] {
        guard let rootUrl = job.parameters["root_url"] else {
            throw MCPCrawlerError.missingParameter("root_url")
        }
        
        let maxDepth = Int(job.parameters["max_depth"] ?? "2") ?? 2
        let maxPages = Int(job.parameters["max_pages"] ?? "10") ?? 10
        let extractContent = Bool(job.parameters["extract_content"] ?? "true") ?? true
        let followLinks = Bool(job.parameters["follow_links"] ?? "true") ?? true
        let rateLimitDelay = Double(job.parameters["rate_limit_delay"] ?? "1.0") ?? 1.0
        
        // Parse include/exclude patterns
        let includePatterns = job.parameters["include_patterns"]?.split(separator: ",").map(String.init) ?? []
        let excludePatterns = job.parameters["exclude_patterns"]?.split(separator: ",").map(String.init) ?? []
        
        let crawlConfig = CrawlConfiguration(
            rootUrl: rootUrl,
            maxDepth: maxDepth,
            maxPages: maxPages,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            extractContent: extractContent,
            followLinks: followLinks,
            rateLimitDelay: rateLimitDelay
        )
        
        let crawlResults = try await crawlWithMCP(config: crawlConfig)
        
        return try crawlResults.map { result in
            try createWebArtifact(from: result, sourceId: job.sourceId, rootUrl: rootUrl)
        }
    }
    
    private func executeMetadataCollectionJob(
        job: JobSpec,
        config: MCPCrawlerConfiguration
    ) async throws -> [WebArtifact] {
        guard let rootUrlsString = job.parameters["root_urls"] else {
            throw MCPCrawlerError.missingParameter("root_urls")
        }
        
        let rootUrls = rootUrlsString.split(separator: ",").map(String.init)
        
        // Collect metadata for all crawled domains
        var domainMetadata: [DomainMetadata] = []
        
        for rootUrl in rootUrls {
            do {
                let metadata = try await collectDomainMetadata(rootUrl)
                domainMetadata.append(metadata)
            } catch {
                logger.warning("Failed to collect metadata for \(rootUrl): \(error.localizedDescription)")
            }
        }
        
        // Create metadata artifact
        let metadata = CrawlSessionMetadata(
            sessionId: job.id,
            rootUrls: rootUrls,
            domains: domainMetadata,
            startTime: Date(),
            endTime: Date()
        )
        
        let metadataArtifact = try createMetadataArtifact(
            metadata: metadata,
            sourceId: job.sourceId
        )
        
        return [metadataArtifact]
    }
    
    // MARK: - MCP Integration
    
    private func crawlWithMCP(config: CrawlConfiguration) async throws -> [CrawlResult] {
        // Connect to MCP server if needed
        let isConnected = await mcpClient.isConnected
        if !isConnected {
            try await mcpClient.connect()
        }
        
        // Prepare crawl request
        let crawlRequest = MCPCrawlRequest(
            url: config.rootUrl,
            maxDepth: config.maxDepth,
            maxPages: config.maxPages,
            includePatterns: config.includePatterns,
            excludePatterns: config.excludePatterns,
            extractContent: config.extractContent,
            followLinks: config.followLinks,
            delay: config.rateLimitDelay
        )
        
        // Execute crawl via MCP
        let mcpResponse = try await mcpClient.crawl(crawlRequest)
        
        return mcpResponse.results.map { mcpResult in
            CrawlResult(
                url: mcpResult.url,
                title: mcpResult.title,
                content: mcpResult.content,
                htmlContent: mcpResult.htmlContent,
                links: mcpResult.links,
                metadata: mcpResult.metadata,
                depth: mcpResult.depth,
                statusCode: mcpResult.statusCode,
                contentType: mcpResult.contentType,
                crawledAt: mcpResult.crawledAt
            )
        }
    }
    
    private func testMCPConnection() async -> Bool {
        do {
            let isConnected = await mcpClient.isConnected
            if !isConnected {
                try await mcpClient.connect()
            }
            
            let healthCheck = try await mcpClient.healthCheck()
            return healthCheck.isHealthy
            
        } catch {
            logger.warning("MCP connection test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func testUrlAccessibility(_ urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        let request = URLRequest(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode < 400
        }
        
        return false
    }
    
    private func previewUrl(_ urlString: String, config: MCPCrawlerConfiguration) async throws -> UrlPreview {
        guard let url = URL(string: urlString) else {
            throw MCPCrawlerError.invalidUrl(urlString)
        }
        
        // Get basic page info via MCP
        let pageInfo = try await mcpClient.getPageInfo(url: urlString)
        
        return UrlPreview(
            url: urlString,
            title: pageInfo.title,
            description: pageInfo.description ?? "Web page content",
            estimatedSize: pageInfo.estimatedSize ?? 50000, // 50KB estimate
            estimatedPages: min(config.maxPages, pageInfo.estimatedPageCount ?? 10)
        )
    }
    
    private func collectDomainMetadata(_ rootUrl: String) async throws -> DomainMetadata {
        guard let url = URL(string: rootUrl) else {
            throw MCPCrawlerError.invalidUrl(rootUrl)
        }
        
        let domain = url.host ?? "unknown"
        let domainInfo = try await mcpClient.getDomainInfo(domain: domain)
        
        return DomainMetadata(
            domain: domain,
            robotsTxt: domainInfo.robotsTxt,
            sitemapUrl: domainInfo.sitemapUrl,
            crawlable: domainInfo.crawlable,
            rateLimit: domainInfo.recommendedDelay,
            lastCrawled: Date()
        )
    }
    
    // MARK: - Artifact Creation
    
    private func createWebArtifact(
        from result: CrawlResult,
        sourceId: UUID,
        rootUrl: String
    ) throws -> WebArtifact {
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "web_crawl",
            sourcePath: result.url,
            additionalContext: [
                "root_url": rootUrl,
                "depth": String(result.depth),
                "status_code": String(result.statusCode)
            ]
        )
        
        let content = ContentBlob(
            format: result.contentType?.contains("html") == true ? .html : .text,
            data: result.content.data(using: .utf8) ?? Data()
        )
        
        let metadata = ArtifactMetadata(
            title: result.title ?? URL(string: result.url)?.lastPathComponent,
            description: "Web page crawled from: \(result.url)",
            tags: ["web", "crawl", "mcp", URL(string: result.url)?.host].compactMap { $0 },
            score: calculateWebPageScore(result: result),
            language: detectLanguage(content: result.content),
            fileSize: result.content.count,
            lineCount: result.content.components(separatedBy: .newlines).count,
            custom: [
                "url": result.url,
                "depth": String(result.depth),
                "status_code": String(result.statusCode),
                "content_type": result.contentType ?? "unknown",
                "links_count": String(result.links.count)
            ]
        )
        
        return WebArtifact(
            id: UUID(),
            type: .webPage,
            version: "1.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: 7 * 24 * 3600, // 7 days for web content
            createdAt: Date(),
            url: result.url,
            htmlContent: result.htmlContent,
            links: result.links,
            crawlMetadata: result.metadata,
            depth: result.depth,
            statusCode: result.statusCode
        )
    }
    
    private func createMetadataArtifact(
        metadata: CrawlSessionMetadata,
        sourceId: UUID
    ) throws -> WebArtifact {
        let metadataData = try JSONEncoder().encode(metadata)
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "web_crawl_metadata"
        )
        
        let artifactMetadata = ArtifactMetadata(
            title: "Crawl Session Metadata",
            description: "Metadata for web crawling session",
            tags: ["web", "crawl", "metadata", "mcp"],
            score: 10, // High score for metadata
            fileSize: metadataData.count,
            custom: [
                "session_id": metadata.sessionId.uuidString,
                "domains_count": String(metadata.domains.count),
                "urls_count": String(metadata.rootUrls.count)
            ]
        )
        
        let content = ContentBlob(
            format: .json,
            data: metadataData
        )
        
        return WebArtifact(
            id: UUID(),
            type: .metadata,
            version: "1.0",
            source: source,
            metadata: artifactMetadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            url: nil,
            htmlContent: nil,
            links: [],
            crawlMetadata: [:],
            depth: 0,
            statusCode: 200
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateWebPageScore(result: CrawlResult) -> Int {
        var score = 1
        
        // Higher score for root pages
        if result.depth == 0 {
            score += 5
        }
        
        // Higher score for pages with good content length
        let contentLength = result.content.count
        if contentLength > 1000 && contentLength < 50000 {
            score += 2
        }
        
        // Higher score for successful responses
        if result.statusCode == 200 {
            score += 1
        }
        
        // Higher score for pages with many outbound links
        if result.links.count > 5 {
            score += 1
        }
        
        return max(1, score)
    }
    
    private func detectLanguage(content: String) -> String? {
        // Simple language detection based on common patterns
        // In a real implementation, you might use a proper language detection library
        
        if content.contains("<html") || content.contains("<!DOCTYPE") {
            return "HTML"
        }
        
        // Default to content type detection
        return nil
    }
    
    private func validate(_ config: MCPCrawlerConfiguration) -> Bool {
        return !config.rootUrls.isEmpty &&
               config.maxDepth > 0 &&
               config.maxPages > 0 &&
               config.rateLimitDelay >= 0
    }
}

// MARK: - Supporting Types

struct WebArtifact: ContentArtifact {
    let id: UUID
    let type: ArtifactType
    let version: String
    let source: ArtifactSource
    let metadata: ArtifactMetadata
    let content: ContentBlob
    let ttl: TimeInterval?
    let createdAt: Date
    
    // Web-specific data
    let url: String?
    let htmlContent: String?
    let links: [String]
    let crawlMetadata: [String: String]
    let depth: Int
    let statusCode: Int
    
    var contentHash: String {
        content.checksum
    }
}

struct MCPCrawlerConfiguration: Codable {
    let rootUrls: [String]
    let maxDepth: Int
    let maxPages: Int
    let includePatterns: [String]
    let excludePatterns: [String]
    let extractContent: Bool
    let followLinks: Bool
    let rateLimitDelay: Double
    let timeoutSeconds: Int
    let respectRobotsTxt: Bool
    
    init(
        rootUrls: [String],
        maxDepth: Int = 2,
        maxPages: Int = 50,
        includePatterns: [String] = [],
        excludePatterns: [String] = [],
        extractContent: Bool = true,
        followLinks: Bool = true,
        rateLimitDelay: Double = 1.0,
        timeoutSeconds: Int = 300,
        respectRobotsTxt: Bool = true
    ) {
        self.rootUrls = rootUrls
        self.maxDepth = maxDepth
        self.maxPages = maxPages
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
        self.extractContent = extractContent
        self.followLinks = followLinks
        self.rateLimitDelay = rateLimitDelay
        self.timeoutSeconds = timeoutSeconds
        self.respectRobotsTxt = respectRobotsTxt
    }
}

struct CrawlConfiguration {
    let rootUrl: String
    let maxDepth: Int
    let maxPages: Int
    let includePatterns: [String]
    let excludePatterns: [String]
    let extractContent: Bool
    let followLinks: Bool
    let rateLimitDelay: Double
}

struct CrawlResult {
    let url: String
    let title: String?
    let content: String
    let htmlContent: String?
    let links: [String]
    let metadata: [String: String]
    let depth: Int
    let statusCode: Int
    let contentType: String?
    let crawledAt: Date
}

struct UrlPreview {
    let url: String
    let title: String?
    let description: String
    let estimatedSize: Int
    let estimatedPages: Int
}

struct DomainMetadata: Codable {
    let domain: String
    let robotsTxt: String?
    let sitemapUrl: String?
    let crawlable: Bool
    let rateLimit: Double?
    let lastCrawled: Date
}

struct CrawlSessionMetadata: Codable {
    let sessionId: UUID
    let rootUrls: [String]
    let domains: [DomainMetadata]
    let startTime: Date
    let endTime: Date
}

enum MCPCrawlerError: LocalizedError {
    case notConfigured
    case invalidConfiguration(String)
    case mcpUnavailable
    case invalidUrl(String)
    case missingParameter(String)
    case crawlFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Plugin is not configured"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .mcpUnavailable:
            return "MCP server is not available"
        case .invalidUrl(let url):
            return "Invalid URL: \(url)"
        case .missingParameter(let param):
            return "Missing parameter: \(param)"
        case .crawlFailed(let message):
            return "Crawl failed: \(message)"
        }
    }
}

// MARK: - MCP Client Implementation

actor MCPClient {
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "MCPClient")
    
    private(set) var isConnected = false
    private let serverUrl = "http://localhost:8000" // Default MCP server URL
    
    func connect() async throws {
        // Implementation would connect to the actual MCP server
        // For now, simulate connection
        try await Task.sleep(for: .seconds(0.1))
        isConnected = true
        logger.info("Connected to MCP server")
    }
    
    func disconnect() async {
        isConnected = false
        logger.info("Disconnected from MCP server")
    }
    
    func healthCheck() async throws -> MCPHealthCheck {
        guard isConnected else {
            throw MCPCrawlerError.mcpUnavailable
        }
        
        // Simulate health check
        return MCPHealthCheck(isHealthy: true, version: "1.0.0")
    }
    
    func getVersion() async -> String {
        return "1.0.0"
    }
    
    func crawl(_ request: MCPCrawlRequest) async throws -> MCPCrawlResponse {
        guard isConnected else {
            throw MCPCrawlerError.mcpUnavailable
        }
        
        // This would integrate with the actual crawl4ai-mcp-server
        // For now, return a mock response
        logger.info("Executing crawl request for: \(request.url)")
        
        // Simulate crawling
        try await Task.sleep(for: .seconds(Double.random(in: 1...3)))
        
        let mockResult = MCPCrawlResult(
            url: request.url,
            title: "Mock Page Title",
            content: "Mock page content for \(request.url)",
            htmlContent: "<html><body>Mock content</body></html>",
            links: ["\(request.url)/page1", "\(request.url)/page2"],
            metadata: ["content-type": "text/html"],
            depth: 0,
            statusCode: 200,
            contentType: "text/html",
            crawledAt: Date()
        )
        
        return MCPCrawlResponse(results: [mockResult])
    }
    
    func getPageInfo(url: String) async throws -> MCPPageInfo {
        guard isConnected else {
            throw MCPCrawlerError.mcpUnavailable
        }
        
        return MCPPageInfo(
            title: "Mock Page",
            description: "A mock page for testing",
            estimatedSize: 50000,
            estimatedPageCount: 10
        )
    }
    
    func getDomainInfo(domain: String) async throws -> MCPDomainInfo {
        guard isConnected else {
            throw MCPCrawlerError.mcpUnavailable
        }
        
        return MCPDomainInfo(
            robotsTxt: "User-agent: *\nDisallow:",
            sitemapUrl: "https://\(domain)/sitemap.xml",
            crawlable: true,
            recommendedDelay: 1.0
        )
    }
}

// MARK: - MCP Protocol Types

struct MCPCrawlRequest {
    let url: String
    let maxDepth: Int
    let maxPages: Int
    let includePatterns: [String]
    let excludePatterns: [String]
    let extractContent: Bool
    let followLinks: Bool
    let delay: Double
}

struct MCPCrawlResponse {
    let results: [MCPCrawlResult]
}

struct MCPCrawlResult {
    let url: String
    let title: String?
    let content: String
    let htmlContent: String?
    let links: [String]
    let metadata: [String: String]
    let depth: Int
    let statusCode: Int
    let contentType: String?
    let crawledAt: Date
}

struct MCPHealthCheck {
    let isHealthy: Bool
    let version: String
}

struct MCPPageInfo {
    let title: String?
    let description: String?
    let estimatedSize: Int?
    let estimatedPageCount: Int?
}

struct MCPDomainInfo {
    let robotsTxt: String?
    let sitemapUrl: String?
    let crawlable: Bool
    let recommendedDelay: Double
}