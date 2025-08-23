import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var selectedAction: DashboardAction?
    
    private var isSetupComplete: Bool {
        whisperState.currentTranscriptionModel != nil &&
        hotkeyManager.selectedHotkey1 != .none &&
        AXIsProcessTrusted() &&
        CGPreflightScreenCaptureAccess()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Section
                headerSection
                
                // Quick Actions Grid
                quickActionsGrid
                
                // Recent Activity
                if isSetupComplete {
                    recentActivitySection
                }
                
                // Getting Started (if not complete)
                if !isSetupComplete {
                    gettingStartedSection
                }
                
                // Backend Status
                backendStatusSection
            }
            .padding(32)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            updateSmartDefaults()
        }
        .sheet(item: $selectedAction) { action in
            actionDetailView(for: action)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to VoiceInk")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered voice-to-text assistant with intelligent context awareness")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSetupComplete {
                    Button("Quick Record") {
                        selectedAction = .record
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                #if DEBUG
                Button("Reset DB") {
                    VoiceInkApp.triggerDatabaseReset()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                #endif
                
                if VoiceInkApp.isDatabaseResetNeeded() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Database reset needed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                
                #if DEBUG
                Button("DB Status") {
                    showDatabaseStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.blue)
                
                Button("Force Delete DB") {
                    VoiceInkApp.forceDeleteDatabase()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                #endif
            }
            
            if !isSetupComplete {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Complete setup to unlock all features")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Quick Actions Grid
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ], spacing: 20) {
            // Record & Transcribe
            ActionCard(
                title: "Record & Transcribe",
                subtitle: "Start voice recording and get real-time transcription with AI enhancement",
                icon: "mic.circle.fill",
                iconColor: .green,
                isEnabled: isSetupComplete
            ) {
                selectedAction = .record
            }
            
            // Project Context
            ActionCard(
                title: "Project Context",
                subtitle: "Manage project sources, Git repositories, and context assembly",
                icon: "folder.badge.gearshape",
                iconColor: .blue,
                showBadge: true,
                badgeText: "\(backendRegistry.projectRegistry?.projects.count ?? 0) Active"
            ) {
                selectedAction = .projectContext
            }
            
            // AI Enhancement
            ActionCard(
                title: "AI Enhancement",
                subtitle: "Configure AI behavior profiles and enhancement settings",
                icon: "wand.and.stars",
                iconColor: .purple
            ) {
                selectedAction = .enhancement
            }
            
            // Power Mode
            ActionCard(
                title: "Power Mode",
                subtitle: "Set up automatic enhancement triggers and application bindings",
                icon: "sparkles.square.fill.on.square",
                iconColor: .orange
            ) {
                selectedAction = .powerMode
            }
            
            // Settings
            ActionCard(
                title: "Settings",
                subtitle: "Configure transcription models, hotkeys, and system preferences",
                icon: "gearshape.fill",
                iconColor: .gray
            ) {
                selectedAction = .settings
            }
            
            // History
            ActionCard(
                title: "History",
                subtitle: "Browse and manage your transcription history and saved content",
                icon: "doc.text.fill",
                iconColor: .indigo
            ) {
                selectedAction = .history
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    selectedAction = .history
                }
                .buttonStyle(.bordered)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    RecentActivityRow(
                        title: "Transcription \(index + 1)",
                        subtitle: "2 minutes ago",
                        icon: "waveform.circle.fill",
                        iconColor: .green
                    )
                }
            }
        }
    }
    
    // MARK: - Getting Started Section
    
    private var gettingStartedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Getting Started")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SetupStepRow(
                    title: "Set up transcription model",
                    isCompleted: whisperState.currentTranscriptionModel != nil,
                    action: { selectedAction = .models }
                )
                
                SetupStepRow(
                    title: "Configure hotkey",
                    isCompleted: hotkeyManager.selectedHotkey1 != .none,
                    action: { selectedAction = .hotkeys }
                )
                
                SetupStepRow(
                    title: "Grant permissions",
                    isCompleted: AXIsProcessTrusted() && CGPreflightScreenCaptureAccess(),
                    action: { selectedAction = .permissions }
                )
            }
        }
    }
    
    // MARK: - Backend Status Section
    
    private var backendStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backend Services")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                BackendStatusIndicator(
                    title: "Project Registry",
                    isActive: backendRegistry.projectRegistry != nil,
                    status: backendRegistry.isInitialized ? "Active" : "Initializing..."
                )
                
                BackendStatusIndicator(
                    title: "Context Assembly",
                    isActive: backendRegistry.contextAssemblyService != nil,
                    status: backendRegistry.isInitialized ? "Active" : "Initializing..."
                )
                
                BackendStatusIndicator(
                    title: "Chat Streams",
                    isActive: backendRegistry.chatStreamService != nil,
                    status: backendRegistry.isInitialized ? "Active" : "Initializing..."
                )
            }
            
            if !backendRegistry.isInitialized {
                ProgressView(value: backendRegistry.initializationProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text(backendRegistry.initializationStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSmartDefaults() {
        let context = UserContext(
            currentWorkingDirectory: getCurrentWorkingDirectory(),
            activeApplications: getActiveApplications(),
            recentProjects: getRecentProjects(),
            systemResources: getSystemResources()
        )
        
        smartDefaults.updateDefaults(for: context)
    }
    
    private func getCurrentWorkingDirectory() -> String? {
        // Get current working directory from shell or recent projects
        return nil
    }
    
    private func getActiveApplications() -> [String] {
        // Get list of active applications
        return []
    }
    
    private func getRecentProjects() -> [String] {
        // Get list of recent projects
        return []
    }
    
    private func getSystemResources() -> SystemResources {
        let memory = ProcessInfo.processInfo.physicalMemory
        let cpuCount = ProcessInfo.processInfo.processorCount
        
        return SystemResources(
            availableMemory: Int64(memory),
            cpuUsage: 0.0, // Would need to calculate actual usage
            diskSpace: 0 // Would need to calculate available disk space
        )
    }
    
    @ViewBuilder
    private func actionDetailView(for action: DashboardAction) -> some View {
        switch action {
        case .record:
            AudioTranscribeView()
        case .projectContext:
            UnifiedContextPanel()
        case .enhancement:
            EnhancementProfileView()
        case .powerMode:
            PowerModeView()
        case .settings:
            SettingsView()
                .environmentObject(whisperState)
        case .history:
            TranscriptionHistoryView()
        case .models:
            ModelManagementView(whisperState: whisperState)
        case .hotkeys:
            KeyboardShortcutView(shortcut: nil) // TODO: Implement proper shortcut handling
        case .permissions:
            PermissionsView()
        }
    }
}

// MARK: - Supporting Views

struct RecentActivityRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct SetupStepRow: View {
    let title: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .secondary)
                .font(.title3)
            
            Text(title)
                .font(.body)
                .foregroundColor(isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if !isCompleted {
                Button("Setup") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct BackendStatusIndicator: View {
    let title: String
    let isActive: Bool
    let status: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Dashboard Actions

enum DashboardAction: Identifiable, CaseIterable {
    case record, projectContext, enhancement, powerMode, settings, history, models, hotkeys, permissions
    
    var id: String { String(describing: self) }
}

// MARK: - Helper Methods

extension DashboardView {
    private func showDatabaseStatus() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.sadiuysal.VoiceInk", isDirectory: true)
        let storeURL = appSupportURL.appendingPathComponent("default.store")
        
        let exists = FileManager.default.fileExists(atPath: storeURL.path)
        let size = exists ? (try? FileManager.default.attributesOfItem(atPath: storeURL.path)[.size] as? Int64) ?? 0 : 0
        
        print("🔍 Database Status:")
        print("  Path: \(storeURL.path)")
        print("  Exists: \(exists)")
        print("  Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        print("  Reset Flag: \(VoiceInkApp.isDatabaseResetNeeded())")
        
        // Also show the path in a more accessible way
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(storeURL.path, forType: .string)
        print("📋 Database path copied to clipboard")
    }
}

#Preview {
    DashboardView()
        .environmentObject(WhisperState(modelContext: try! ModelContainer(for: Project.self).mainContext))
        .environmentObject(HotkeyManager(whisperState: WhisperState(modelContext: try! ModelContainer(for: Project.self).mainContext)))
}
