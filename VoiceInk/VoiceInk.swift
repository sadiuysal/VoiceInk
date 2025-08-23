import SwiftUI
import SwiftData
import Sparkle
import AppKit
import OSLog

@main
struct VoiceInkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    
    // Method to trigger database reset
    static func triggerDatabaseReset() {
        UserDefaults.standard.set(true, forKey: "ShouldResetDatabaseForNewSchema")
        print("🔄 Database reset triggered for next app launch")
        
        // Also try to delete the database file immediately if possible
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.sadiuysal.VoiceInk", isDirectory: true) {
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: storeURL)
            print("🗑️ Database file deleted immediately")
        }
    }
    
    // Method to check if database reset is needed
    static func isDatabaseResetNeeded() -> Bool {
        return UserDefaults.standard.bool(forKey: "ShouldResetDatabaseForNewSchema")
    }
    
    // Method to force delete database file
    static func forceDeleteDatabase() {
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.sadiuysal.VoiceInk", isDirectory: true) {
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: storeURL)
            print("🗑️ Database file force deleted")
            
            // Also set the reset flag
            UserDefaults.standard.set(true, forKey: "ShouldResetDatabaseForNewSchema")
        }
    }
    
    @StateObject private var whisperState: WhisperState
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var updaterViewModel: UpdaterViewModel
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var aiService = AIService()
    @StateObject private var enhancementService: AIEnhancementService
    @StateObject private var activeWindowService = ActiveWindowService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Audio cleanup manager for automatic deletion of old audio files
    private let audioCleanupManager = AudioCleanupManager.shared
    
    // Transcription auto-cleanup service for zero data retention
    private let transcriptionAutoCleanupService = TranscriptionAutoCleanupService.shared
    
    init() {
        // Create app-specific Application Support directory URL
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.sadiuysal.VoiceInk", isDirectory: true)
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        // For development/testing: Force database reset if needed
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-database") {
            UserDefaults.standard.set(true, forKey: "ShouldResetDatabaseForNewSchema")
            print("🔧 Debug mode: Database reset flag set")
        }
        
        // Check for other command line options
        for argument in ProcessInfo.processInfo.arguments {
            switch argument {
            case "--reset-database":
                UserDefaults.standard.set(true, forKey: "ShouldResetDatabaseForNewSchema")
                print("🔧 Command line: Database reset flag set")
            case "--help":
                print("🔧 Available command line options:")
                print("  --reset-database: Reset database on next launch")
                print("  --help: Show this help message")
            default:
                break
            }
        }
        #endif
        
        // Configure SwiftData to use the conventional location
        let storeURL = appSupportURL.appendingPathComponent("default.store")
        
        do {
            let schema = Schema([
                Transcription.self,
                Project.self,
                ContextSource.self,
                ContextPack.self,
                DictionaryEntry.self,
                ContentArtifactModel.self,
                IngestionJobModel.self,
                ChatStreamModel.self
            ])
            
            // Check if we need to reset the database due to schema changes
            let shouldResetDatabase = UserDefaults.standard.bool(forKey: "ShouldResetDatabaseForNewSchema")
            
            if shouldResetDatabase {
                // Delete the old database file
                try? FileManager.default.removeItem(at: storeURL)
                print("🗑️ Deleted old database for schema reset")
                
                // Reset the flag
                UserDefaults.standard.set(false, forKey: "ShouldResetDatabaseForNewSchema")
            }
            
            let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Print SwiftData storage location
            if let url = container.mainContext.container.configurations.first?.url {
                print("💾 SwiftData storage location: \(url.path)")
            }
            
        } catch {
            print("❌ Failed to create ModelContainer: \(error.localizedDescription)")
            
            // If it's a migration error, suggest resetting the database
            if let nsError = error as NSError?,
               nsError.domain == NSCocoaErrorDomain && nsError.code == 134110 {
                print("🔄 Migration error detected. Setting flag to reset database on next launch.")
                UserDefaults.standard.set(true, forKey: "ShouldResetDatabaseForNewSchema")
                
                // Try to create a fresh container without the problematic models
                do {
                    let minimalSchema = Schema([
                        Transcription.self,
                        Project.self,
                        ContextSource.self,
                        ContextPack.self,
                        DictionaryEntry.self,
                        ContentArtifactModel.self,
                        IngestionJobModel.self,
                        ChatStreamModel.self
                    ])
                    
                    let minimalConfiguration = ModelConfiguration(schema: minimalSchema, url: storeURL)
                    container = try ModelContainer(for: minimalSchema, configurations: [minimalConfiguration])
                    print("✅ Created minimal ModelContainer successfully")
                } catch {
                    fatalError("Failed to create even minimal ModelContainer: \(error.localizedDescription)")
                }
            } else {
                fatalError("Failed to create ModelContainer for Transcription: \(error.localizedDescription)")
            }
        }
        
        // Initialize services with proper sharing of instances
        let aiService = AIService()
        _aiService = StateObject(wrappedValue: aiService)
        
        let updaterViewModel = UpdaterViewModel()
        _updaterViewModel = StateObject(wrappedValue: updaterViewModel)
        
        let enhancementService = AIEnhancementService(aiService: aiService, modelContext: container.mainContext)
        _enhancementService = StateObject(wrappedValue: enhancementService)
        
        let whisperState = WhisperState(modelContext: container.mainContext, enhancementService: enhancementService)
        _whisperState = StateObject(wrappedValue: whisperState)
        
        let hotkeyManager = HotkeyManager(whisperState: whisperState)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
        
        let menuBarManager = MenuBarManager(
            updaterViewModel: updaterViewModel,
            whisperState: whisperState,
            container: container,
            enhancementService: enhancementService,
            aiService: aiService,
            hotkeyManager: hotkeyManager
        )
        _menuBarManager = StateObject(wrappedValue: menuBarManager)
        
        let activeWindowService = ActiveWindowService.shared
        activeWindowService.configure(with: enhancementService)
        activeWindowService.configureWhisperState(whisperState)
        _activeWindowService = StateObject(wrappedValue: activeWindowService)
        
        // Configure ContextIndexStore with shared ModelContainer
        ContextIndexStore.shared.configure(with: container)
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(whisperState)
                    .environmentObject(hotkeyManager)
                    .environmentObject(updaterViewModel)
                    .environmentObject(menuBarManager)
                    .environmentObject(aiService)
                    .environmentObject(enhancementService)
                    .modelContainer(container)
                    .onAppear {
                        updaterViewModel.silentlyCheckForUpdates()
                        
                        // Initialize new backend services
                        Task {
                            do {
                                try await VoiceInkBackendRegistry.shared.initialize(with: container)
                            } catch {
                                print("⚠️ Backend initialization failed: \(error.localizedDescription)")
                            }
                        }
                        
                        // Add a simple way to reset database in development
                        #if DEBUG
                        if UserDefaults.standard.bool(forKey: "ShouldResetDatabaseForNewSchema") {
                            print("🔄 Database reset flag is set. App will reset database on next launch.")
                        }
                        #endif
                        
                        AnnouncementsService.shared.start()
                        
                        // Start the transcription auto-cleanup service (handles immediate and scheduled transcript deletion)
                        transcriptionAutoCleanupService.startMonitoring(modelContext: container.mainContext)
                        
                        // Start the automatic audio cleanup process only if transcript cleanup is not enabled
                        if !UserDefaults.standard.bool(forKey: "IsTranscriptionCleanupEnabled") {
                            audioCleanupManager.startAutomaticCleanup(modelContext: container.mainContext)
                        }
                    }
                    .background(WindowAccessor { window in
                        WindowManager.shared.configureWindow(window)
                    })
                    .onDisappear {
                        AnnouncementsService.shared.stop()
                        whisperState.unloadModel()
                        
                        // Stop the transcription auto-cleanup service
                        transcriptionAutoCleanupService.stopMonitoring()
                        
                        // Stop the automatic audio cleanup process
                        audioCleanupManager.stopAutomaticCleanup()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(hotkeyManager)
                    .environmentObject(whisperState)
                    .environmentObject(aiService)
                    .environmentObject(enhancementService)
                    .frame(minWidth: 880, minHeight: 780)
                    .background(WindowAccessor { window in
                        // Ensure this is called only once or is idempotent
                        if window.title != "VoiceInk Onboarding" { // Prevent re-configuration
                            WindowManager.shared.configureOnboardingPanel(window)
                        }
                    })
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updaterViewModel: updaterViewModel)
            }
        }
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(whisperState)
                .environmentObject(hotkeyManager)
                .environmentObject(menuBarManager)
                .environmentObject(updaterViewModel)
                .environmentObject(aiService)
                .environmentObject(enhancementService)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 22
                $0.size.width = 22 / ratio
                return $0
            }(NSImage(named: "menuBarIcon")!)

            Image(nsImage: image)
        }
        .menuBarExtraStyle(.menu)
        
        #if DEBUG
        WindowGroup("Debug") {
            Button("Toggle Menu Bar Only") {
                menuBarManager.isMenuBarOnly.toggle()
            }
        }
        #endif
    }
}

class UpdaterViewModel: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Enable automatic update checking
        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.updateCheckInterval = 24 * 60 * 60
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    func checkForUpdates() {
        // This is for manual checks - will show UI
        updaterController.checkForUpdates(nil)
    }
    
    func silentlyCheckForUpdates() {
        // This checks for updates in the background without showing UI unless an update is found
        updaterController.updater.checkForUpdatesInBackground()
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel
    
    var body: some View {
        Button("Check for Updates…", action: updaterViewModel.checkForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}



