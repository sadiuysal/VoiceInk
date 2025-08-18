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