import Foundation

extension UserDefaults {
    enum Keys {
        static let aiProviderApiKey = "VoiceInkAIProviderKey"
        static let licenseKey = "VoiceInkLicense"
        static let trialStartDate = "VoiceInkTrialStartDate"
        static let audioInputMode = "audioInputMode"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let prioritizedDevices = "prioritizedDevices"
        // Filesystem context
        static let useFilesystemContext = "UseFilesystemContext"
        static let manualProjectRootPath = "ManualProjectRootPath"
        
        // Chat Harvest Settings
        static let autoCaptureChat = "AutoCaptureCursorChat"
        static let chatLastMessages = "ChatHarvestLastMessages"
        static let chatTokenCap = "ChatHarvestTokenCap"
        static let chatCodeOnly = "ChatHarvestCodeOnly"
        
        // Project Context Settings
        static let defaultProjectRoot = "DefaultProjectRoot"
        static let autoDetectProject = "AutoDetectProjectContext"
        static let ingestionFileSizeLimit = "IngestionFileSizeLimit"
        
        // Sync Settings
        static let autoSyncInterval = "AutoSyncInterval"
        static let backgroundSync = "BackgroundSyncEnabled"
        static let maxConcurrentIngestions = "MaxConcurrentIngestions"
        
        // Advanced Settings
        static let chatHarvestTimeout = "ChatHarvestTimeoutMs"
        static let contextTokenBudget = "ContextTokenBudget"
        static let enableFilesystemMonitoring = "EnableFilesystemMonitoring"
        static let enableContextInspector = "EnableContextInspector"
        static let fsRefreshTTLSeconds = "FSRefreshTTLSeconds"
        static let fsTermsLimit = "FSTermsLimit"
        static let enableFSIncremental = "EnableFSIncremental"
        // GitIngest integration
        static let useGitIngest = "UseGitIngest"
        static let gitIngestTimeoutSeconds = "GitIngestTimeoutSeconds"
        static let gitIngestIncludeSubmodules = "GitIngestIncludeSubmodules"
        static let gitIngestIncludeGitignored = "GitIngestIncludeGitignored"
        static let gitIngestToken = "GitIngestToken"
        static let gitIngestAutoSync = "GitIngestAutoSync"
        static let gitIngestSyncInterval = "GitIngestSyncInterval"
    }
    
    // MARK: - AI Provider API Key
    var aiProviderApiKey: String? {
        get { string(forKey: Keys.aiProviderApiKey) }
        set { setValue(newValue, forKey: Keys.aiProviderApiKey) }
    }
    
    // MARK: - License Key
    var licenseKey: String? {
        get { string(forKey: Keys.licenseKey) }
        set { setValue(newValue, forKey: Keys.licenseKey) }
    }
    
    // MARK: - Trial Start Date
    var trialStartDate: Date? {
        get { object(forKey: Keys.trialStartDate) as? Date }
        set { setValue(newValue, forKey: Keys.trialStartDate) }
    }

    // MARK: - Audio Input Mode
    var audioInputModeRawValue: String? {
        get { string(forKey: Keys.audioInputMode) }
        set { setValue(newValue, forKey: Keys.audioInputMode) }
    }

    // MARK: - Selected Audio Device UID
    var selectedAudioDeviceUID: String? {
        get { string(forKey: Keys.selectedAudioDeviceUID) }
        set { setValue(newValue, forKey: Keys.selectedAudioDeviceUID) }
    }

    // MARK: - Prioritized Devices
    var prioritizedDevicesData: Data? {
        get { data(forKey: Keys.prioritizedDevices) }
        set { setValue(newValue, forKey: Keys.prioritizedDevices) }
    }

    // MARK: - Filesystem Context
    var useFilesystemContext: Bool {
        get { bool(forKey: Keys.useFilesystemContext) }
        set { setValue(newValue, forKey: Keys.useFilesystemContext) }
    }

    var manualProjectRootPath: String? {
        get { string(forKey: Keys.manualProjectRootPath) }
        set { setValue(newValue, forKey: Keys.manualProjectRootPath) }
    }
    
    // MARK: - Chat Harvest Settings
    var autoCaptureChat: Bool {
        get { 
            // Default to true if key doesn't exist
            if object(forKey: Keys.autoCaptureChat) == nil {
                return true
            }
            return bool(forKey: Keys.autoCaptureChat) 
        }
        set { setValue(newValue, forKey: Keys.autoCaptureChat) }
    }
    
    var chatLastMessages: Int {
        get { 
            let value = integer(forKey: Keys.chatLastMessages)
            return value == 0 ? 8 : value // Default to 8 if not set
        }
        set { setValue(newValue, forKey: Keys.chatLastMessages) }
    }
    
    var chatTokenCap: Int {
        get { 
            let value = integer(forKey: Keys.chatTokenCap)
            return value == 0 ? 512 : value // Default to 512 if not set
        }
        set { setValue(newValue, forKey: Keys.chatTokenCap) }
    }
    
    var chatCodeOnly: Bool {
        get { bool(forKey: Keys.chatCodeOnly) }
        set { setValue(newValue, forKey: Keys.chatCodeOnly) }
    }
    
    // MARK: - Project Context Settings
    var defaultProjectRoot: String? {
        get { string(forKey: Keys.defaultProjectRoot) }
        set { setValue(newValue, forKey: Keys.defaultProjectRoot) }
    }
    
    var autoDetectProject: Bool {
        get { 
            if object(forKey: Keys.autoDetectProject) == nil {
                return true
            }
            return bool(forKey: Keys.autoDetectProject) 
        }
        set { setValue(newValue, forKey: Keys.autoDetectProject) }
    }
    
    var ingestionFileSizeLimit: Int {
        get { 
            let value = integer(forKey: Keys.ingestionFileSizeLimit)
            return value == 0 ? 1_048_576 : value // Default to 1MB
        }
        set { setValue(newValue, forKey: Keys.ingestionFileSizeLimit) }
    }
    
    // MARK: - Sync Settings
    var autoSyncInterval: String {
        get { string(forKey: Keys.autoSyncInterval) ?? "manual" }
        set { setValue(newValue, forKey: Keys.autoSyncInterval) }
    }
    
    var backgroundSync: Bool {
        get { 
            if object(forKey: Keys.backgroundSync) == nil {
                return true
            }
            return bool(forKey: Keys.backgroundSync) 
        }
        set { setValue(newValue, forKey: Keys.backgroundSync) }
    }
    
    var maxConcurrentIngestions: Int {
        get { 
            let value = integer(forKey: Keys.maxConcurrentIngestions)
            return value == 0 ? 2 : value // Default to 2
        }
        set { setValue(newValue, forKey: Keys.maxConcurrentIngestions) }
    }
    
    // MARK: - Advanced Settings
    var chatHarvestTimeout: Int {
        get { 
            let value = integer(forKey: Keys.chatHarvestTimeout)
            return value == 0 ? 150 : value // Default to 150ms
        }
        set { setValue(newValue, forKey: Keys.chatHarvestTimeout) }
    }
    
    var contextTokenBudget: Int {
        get { 
            let value = integer(forKey: Keys.contextTokenBudget)
            return value == 0 ? 2048 : value // Default to 2048
        }
        set { setValue(newValue, forKey: Keys.contextTokenBudget) }
    }
    
    var enableFilesystemMonitoring: Bool {
        get { bool(forKey: Keys.enableFilesystemMonitoring) }
        set { setValue(newValue, forKey: Keys.enableFilesystemMonitoring) }
    }

    var enableContextInspector: Bool {
        get { bool(forKey: Keys.enableContextInspector) }
        set { setValue(newValue, forKey: Keys.enableContextInspector) }
    }

    var fsRefreshTTLSeconds: Int {
        get { integer(forKey: Keys.fsRefreshTTLSeconds) == 0 ? 600 : integer(forKey: Keys.fsRefreshTTLSeconds) }
        set { setValue(newValue, forKey: Keys.fsRefreshTTLSeconds) }
    }

    	var fsTermsLimit: Int {
		get { integer(forKey: Keys.fsTermsLimit) == 0 ? 500 : integer(forKey: Keys.fsTermsLimit) }
		set { setValue(newValue, forKey: Keys.fsTermsLimit) }
	}

    var enableFSIncremental: Bool {
        get { bool(forKey: Keys.enableFSIncremental) }
        set { setValue(newValue, forKey: Keys.enableFSIncremental) }
    }
    
    // MARK: - GitIngest Integration
    var useGitIngest: Bool {
        get { bool(forKey: Keys.useGitIngest) }
        set { setValue(newValue, forKey: Keys.useGitIngest) }
    }
    
    var gitIngestTimeoutSeconds: Int {
        get { integer(forKey: Keys.gitIngestTimeoutSeconds) == 0 ? 300 : integer(forKey: Keys.gitIngestTimeoutSeconds) }
        set { setValue(newValue, forKey: Keys.gitIngestTimeoutSeconds) }
    }
    
    var gitIngestIncludeSubmodules: Bool {
        get { bool(forKey: Keys.gitIngestIncludeSubmodules) }
        set { setValue(newValue, forKey: Keys.gitIngestIncludeSubmodules) }
    }
    
    var gitIngestIncludeGitignored: Bool {
        get { bool(forKey: Keys.gitIngestIncludeGitignored) }
        set { setValue(newValue, forKey: Keys.gitIngestIncludeGitignored) }
    }
    
    var gitIngestToken: String? {
        get { string(forKey: Keys.gitIngestToken) }
        set { setValue(newValue, forKey: Keys.gitIngestToken) }
    }
    
    var gitIngestAutoSync: Bool {
        get { bool(forKey: Keys.gitIngestAutoSync) }
        set { setValue(newValue, forKey: Keys.gitIngestAutoSync) }
    }
    
    var gitIngestSyncInterval: TimeInterval {
        get { 
            let stored = double(forKey: Keys.gitIngestSyncInterval)
            return stored == 0 ? 3600 : stored // Default 1 hour
        }
        set { setValue(newValue, forKey: Keys.gitIngestSyncInterval) }
    }
} 