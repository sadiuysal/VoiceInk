import Foundation
import OSLog

@MainActor
final class SmartDefaultsService: ObservableObject {
    static let shared = SmartDefaultsService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "SmartDefaults")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Published Properties
    
    @Published var suggestedProjectName: String = ""
    @Published var suggestedProjectPath: String = ""
    @Published var suggestedEnhancementProfile: EnhancementProfileSuggestion = .balanced
    @Published var suggestedHotkey: HotkeySuggestion = .commandShiftR
    @Published var suggestedModel: ModelSuggestion = .whisperMedium
    
    // MARK: - Private Properties
    
    private var userBehaviorTracker: UserBehaviorTracker
    private var contextAnalyzer: ContextAnalyzer
    
    private init() {
        self.userBehaviorTracker = UserBehaviorTracker()
        self.contextAnalyzer = ContextAnalyzer()
        loadSmartDefaults()
    }
    
    // MARK: - Public Methods
    
    func updateDefaults(for context: UserContext) {
        Task {
            await analyzeContext(context)
            await suggestOptimalDefaults()
        }
    }
    
    func getProjectDefaults() -> ProjectDefaults {
        return ProjectDefaults(
            name: suggestedProjectName,
            path: suggestedProjectPath,
            enhancementProfile: suggestedEnhancementProfile,
            hotkey: suggestedHotkey,
            model: suggestedModel
        )
    }
    
    func getEnhancementDefaults() -> EnhancementDefaults {
        return EnhancementDefaults(
            profile: suggestedEnhancementProfile,
            model: suggestedModel,
            autoEnhance: true,
            contextAware: true
        )
    }
    
    func getRecordingDefaults() -> RecordingDefaults {
        return RecordingDefaults(
            model: suggestedModel,
            quality: .high,
            autoEnhance: true,
            saveToHistory: true
        )
    }
    
    // MARK: - Private Methods
    
    private func loadSmartDefaults() {
        suggestedProjectName = userDefaults.string(forKey: "SmartDefaults.ProjectName") ?? ""
        suggestedProjectPath = userDefaults.string(forKey: "SmartDefaults.ProjectPath") ?? ""
        
        if let profileRaw = userDefaults.string(forKey: "SmartDefaults.EnhancementProfile"),
           let profile = EnhancementProfileSuggestion(rawValue: profileRaw) {
            suggestedEnhancementProfile = profile
        }
        
        if let hotkeyRaw = userDefaults.string(forKey: "SmartDefaults.Hotkey"),
           let hotkey = HotkeySuggestion(rawValue: hotkeyRaw) {
            suggestedHotkey = hotkey
        }
        
        if let modelRaw = userDefaults.string(forKey: "SmartDefaults.Model"),
           let model = ModelSuggestion(rawValue: modelRaw) {
            suggestedModel = model
        }
    }
    
    private func analyzeContext(_ context: UserContext) async {
        // Analyze current working directory
        if let cwd = context.currentWorkingDirectory {
            let projectName = await contextAnalyzer.extractProjectName(from: cwd)
            let projectPath = await contextAnalyzer.validateProjectPath(cwd)
            
            await MainActor.run {
                suggestedProjectName = projectName
                suggestedProjectPath = projectPath
            }
        }
        
        // Analyze recent usage patterns
        let usagePatterns = await userBehaviorTracker.getRecentPatterns()
        updateDefaultsFromPatterns(usagePatterns)
    }
    
    private func suggestOptimalDefaults() async {
        // Suggest optimal enhancement profile based on project type
        let projectType = await contextAnalyzer.detectProjectType()
        let optimalProfile = getOptimalProfile(for: projectType)
        await MainActor.run {
            suggestedEnhancementProfile = optimalProfile
        }
        
        // Suggest optimal model based on performance and accuracy needs
        let optimalModel = await getOptimalModel()
        await MainActor.run {
            suggestedModel = optimalModel
        }
        
        // Save suggestions
        saveSmartDefaults()
    }
    
    private func updateDefaultsFromPatterns(_ patterns: [UsagePattern]) {
        // Analyze hotkey usage patterns
        let hotkeyPatterns = patterns.filter { $0.type == .hotkey }
        if let mostUsedHotkey = getMostUsedHotkey(from: hotkeyPatterns) {
            suggestedHotkey = mostUsedHotkey
        }
        
        // Analyze enhancement profile usage
        let profilePatterns = patterns.filter { $0.type == .enhancement }
        if let mostUsedProfile = getMostUsedProfile(from: profilePatterns) {
            suggestedEnhancementProfile = mostUsedProfile
        }
    }
    
    private func getOptimalProfile(for projectType: ProjectType) -> EnhancementProfileSuggestion {
        switch projectType {
        case .webApp:
            return .webDevelopment
        case .mobileApp:
            return .mobileDevelopment
        case .desktopApp:
            return .desktopDevelopment
        case .library:
            return .codeReview
        case .documentation:
            return .documentation
        case .unknown:
            return .balanced
        }
    }
    
    private func getOptimalModel() async -> ModelSuggestion {
        // Check system performance
        let systemPerformance = await getSystemPerformance()
        
        switch systemPerformance {
        case .high:
            return .whisperLarge
        case .medium:
            return .whisperMedium
        case .low:
            return .whisperSmall
        }
    }
    
    private func getSystemPerformance() async -> SystemPerformance {
        // Simple performance check based on available memory and CPU
        let memoryGB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024
        let processorCount = ProcessInfo.processInfo.processorCount
        
        if memoryGB >= 16 && processorCount >= 8 {
            return .high
        } else if memoryGB >= 8 && processorCount >= 4 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func getMostUsedHotkey(from patterns: [UsagePattern]) -> HotkeySuggestion? {
        let hotkeyCounts = patterns.reduce(into: [HotkeySuggestion: Int]()) { counts, pattern in
            if let hotkey = HotkeySuggestion(rawValue: pattern.value) {
                counts[hotkey, default: 0] += 1
            }
        }
        
        return hotkeyCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func getMostUsedProfile(from patterns: [UsagePattern]) -> EnhancementProfileSuggestion? {
        let profileCounts = patterns.reduce(into: [EnhancementProfileSuggestion: Int]()) { counts, pattern in
            if let profile = EnhancementProfileSuggestion(rawValue: pattern.value) {
                counts[profile, default: 0] += 1
            }
        }
        
        return profileCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func saveSmartDefaults() {
        userDefaults.set(suggestedProjectName, forKey: "SmartDefaults.ProjectName")
        userDefaults.set(suggestedProjectPath, forKey: "SmartDefaults.ProjectPath")
        userDefaults.set(suggestedEnhancementProfile.rawValue, forKey: "SmartDefaults.EnhancementProfile")
        userDefaults.set(suggestedHotkey.rawValue, forKey: "SmartDefaults.Hotkey")
        userDefaults.set(suggestedModel.rawValue, forKey: "SmartDefaults.Model")
    }
}

// MARK: - Supporting Types

struct ProjectDefaults {
    let name: String
    let path: String
    let enhancementProfile: EnhancementProfileSuggestion
    let hotkey: HotkeySuggestion
    let model: ModelSuggestion
}

struct EnhancementDefaults {
    let profile: EnhancementProfileSuggestion
    let model: ModelSuggestion
    let autoEnhance: Bool
    let contextAware: Bool
}

struct RecordingDefaults {
    let model: ModelSuggestion
    let quality: RecordingQuality
    let autoEnhance: Bool
    let saveToHistory: Bool
}

enum EnhancementProfileSuggestion: String, CaseIterable {
    case balanced = "Balanced"
    case webDevelopment = "Web Development"
    case mobileDevelopment = "Mobile Development"
    case desktopDevelopment = "Desktop Development"
    case codeReview = "Code Review"
    case documentation = "Documentation"
    case meetingNotes = "Meeting Notes"
    case creativeWriting = "Creative Writing"
}

enum HotkeySuggestion: String, CaseIterable {
    case commandShiftR = "⌘⇧R"
    case commandShiftT = "⌘⇧T"
    case commandShiftV = "⌘⇧V"
    case commandShiftM = "⌘⇧M"
    case commandOptionR = "⌘⌥R"
    case commandOptionT = "⌘⌥T"
}

enum ModelSuggestion: String, CaseIterable {
    case whisperSmall = "Whisper Small"
    case whisperMedium = "Whisper Medium"
    case whisperLarge = "Whisper Large"
    case whisperTiny = "Whisper Tiny"
}

enum RecordingQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum SystemPerformance {
    case low, medium, high
}

enum ProjectType {
    case webApp, mobileApp, desktopApp, library, documentation, unknown
}

struct UserContext {
    let currentWorkingDirectory: String?
    let activeApplications: [String]
    let recentProjects: [String]
    let systemResources: SystemResources
}

struct SystemResources {
    let availableMemory: Int64
    let cpuUsage: Double
    let diskSpace: Int64
}

struct UsagePattern {
    let type: PatternType
    let value: String
    let timestamp: Date
    let frequency: Int
}

enum PatternType {
    case hotkey, enhancement, model, project
}

// MARK: - Helper Classes

@MainActor
private final class UserBehaviorTracker: ObservableObject {
    func getRecentPatterns() async -> [UsagePattern] {
        // Implementation would track user behavior over time
        // For now, return empty array
        return []
    }
}

@MainActor
private final class ContextAnalyzer: ObservableObject {
    func extractProjectName(from path: String) async -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? "Untitled Project"
    }
    
    func validateProjectPath(_ path: String) async -> String {
        // Check if path exists and is accessible
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            return path
        }
        return ""
    }
    
    func detectProjectType() async -> ProjectType {
        // Analyze project structure to determine type
        // For now, return unknown
        return .unknown
    }
}
