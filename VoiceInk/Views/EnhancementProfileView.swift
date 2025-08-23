import SwiftUI

struct EnhancementProfileView: View {
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var selectedProfile: EnhancementProfileSuggestion = .balanced
    @State private var selectedModel: ModelSuggestion = .whisperMedium
    @State private var autoEnhance = true
    @State private var contextAware = true
    @State private var triggerPatterns: [String] = []
    @State private var showingProfileSetup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("AI Enhancement Profiles")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("New Profile") {
                        showingProfileSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Text("Configure AI behavior profiles for different types of content and workflows")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Current Profile
                    currentProfileSection
                    
                    // Available Profiles
                    availableProfilesSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding(24)
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
        .sheet(isPresented: $showingProfileSetup) {
            EnhancementSetupWorkflow()
        }
    }
    
    // MARK: - Current Profile Section
    
    private var currentProfileSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Current Profile")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedProfile.rawValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(getProfileDescription(selectedProfile))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(selectedModel.rawValue)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("Model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-enhance: \(autoEnhance ? "On" : "Off")")
                            .font(.body)
                        
                        Text("Context-aware: \(contextAware ? "On" : "Off")")
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Button("Edit") {
                        showingProfileSetup = true
                    }
                    .buttonStyle(.bordered)
                }
                
                if !triggerPatterns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trigger Patterns:")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        HStack {
                            ForEach(triggerPatterns, id: \.self) { pattern in
                                Text(pattern)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
    
    // MARK: - Available Profiles Section
    
    private var availableProfilesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Available Profiles")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(EnhancementProfileSuggestion.allCases, id: \.self) { profile in
                    ProfileCard(
                        profile: profile,
                        isSelected: selectedProfile == profile,
                        isRecommended: profile == smartDefaults.suggestedEnhancementProfile,
                        onSelect: { selectedProfile = profile }
                    )
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                Button("Test Profile") {
                    testCurrentProfile()
                }
                .buttonStyle(.bordered)
                
                Button("Export Profile") {
                    exportCurrentProfile()
                }
                .buttonStyle(.bordered)
                
                Button("Import Profile") {
                    importProfile()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentProfile() {
        let userDefaults = UserDefaults.standard
        
        if let profileRaw = userDefaults.string(forKey: "EnhancementProfile.Type"),
           let profile = EnhancementProfileSuggestion(rawValue: profileRaw) {
            selectedProfile = profile
        }
        
        if let modelRaw = userDefaults.string(forKey: "EnhancementProfile.Model"),
           let model = ModelSuggestion(rawValue: modelRaw) {
            selectedModel = model
        }
        
        autoEnhance = userDefaults.bool(forKey: "EnhancementProfile.AutoEnhance")
        contextAware = userDefaults.bool(forKey: "EnhancementProfile.ContextAware")
        triggerPatterns = userDefaults.stringArray(forKey: "EnhancementProfile.Triggers") ?? []
    }
    
    private func getProfileDescription(_ profile: EnhancementProfileSuggestion) -> String {
        switch profile {
        case .balanced:
            return "Balanced performance and accuracy for general use"
        case .webDevelopment:
            return "Optimized for web development workflows with code context"
        case .mobileDevelopment:
            return "Tailored for mobile app development and platform-specific patterns"
        case .desktopDevelopment:
            return "Specialized for desktop application development and system integration"
        case .codeReview:
            return "Enhanced for code review and analysis with technical terminology"
        case .documentation:
            return "Focused on documentation and writing with clear formatting"
        case .meetingNotes:
            return "Optimized for meeting transcription and note-taking"
        case .creativeWriting:
            return "Enhanced for creative writing and content creation"
        }
    }
    
    private func testCurrentProfile() {
        // Test the current profile with a sample transcription
        // This would integrate with the backend testing capabilities
    }
    
    private func exportCurrentProfile() {
        // Export the current profile configuration
        // This would create a shareable configuration file
    }
    
    private func importProfile() {
        // Import a profile configuration
        // This would allow users to share and reuse profiles
    }
}

// MARK: - Supporting Views

struct ProfileCard: View {
    let profile: EnhancementProfileSuggestion
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                HStack {
                    Text(profile.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(getProfileDescription(profile))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                Spacer()
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getProfileDescription(_ profile: EnhancementProfileSuggestion) -> String {
        switch profile {
        case .balanced:
            return "Balanced performance and accuracy for general use"
        case .webDevelopment:
            return "Optimized for web development workflows"
        case .mobileDevelopment:
            return "Tailored for mobile app development"
        case .desktopDevelopment:
            return "Specialized for desktop applications"
        case .codeReview:
            return "Enhanced for code review and analysis"
        case .documentation:
            return "Focused on documentation and writing"
        case .meetingNotes:
            return "Optimized for meeting transcription"
        case .creativeWriting:
            return "Enhanced for creative writing"
        }
    }
}

#Preview {
    EnhancementProfileView()
}
