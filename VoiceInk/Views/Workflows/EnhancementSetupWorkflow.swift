import SwiftUI

struct EnhancementSetupWorkflow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var enhancementProfile: EnhancementProfileSuggestion = .balanced
    @State private var selectedModel: ModelSuggestion = .whisperMedium
    @State private var autoEnhance = true
    @State private var contextAware = true
    @State private var triggerPatterns: [String] = []
    @State private var newPattern = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("AI Enhancement Setup")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Create Profile") {
                            createEnhancementProfile()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreateProfile)
                    }
                    
                    Text("Configure AI enhancement behavior with intelligent defaults and context awareness")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                
                // Progress Steps
                ProgressStepsView(
                    steps: ["Profile", "Model", "Behavior", "Triggers"],
                    currentStep: 1
                )
                .padding(.horizontal, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Enhancement Profile Selection
                        enhancementProfileSection
                        
                        // Model Selection
                        modelSelectionSection
                        
                        // Behavior Configuration
                        behaviorConfigurationSection
                        
                        // Trigger Configuration
                        triggerConfigurationSection
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            loadSmartDefaults()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Enhancement Profile Section
    
    private var enhancementProfileSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enhancement Profile")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(EnhancementProfileSuggestion.allCases, id: \.self) { profile in
                    EnhancementProfileCard(
                        profile: profile,
                        isSelected: enhancementProfile == profile,
                        isRecommended: profile == smartDefaults.suggestedEnhancementProfile,
                        onSelect: { enhancementProfile = profile }
                    )
                }
            }
            
            if enhancementProfile != .balanced {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("This profile will optimize AI enhancement for \(enhancementProfile.rawValue.lowercased()) workflows")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Model Selection Section
    
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Transcription Model")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ForEach(ModelSuggestion.allCases, id: \.self) { model in
                    ModelSelectionCard(
                        model: model,
                        isSelected: selectedModel == model,
                        isRecommended: model == smartDefaults.suggestedModel,
                        onSelect: { selectedModel = model }
                    )
                }
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Selection Guide")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Smaller models are faster but less accurate. Larger models are more accurate but slower.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }
    
    // MARK: - Behavior Configuration Section
    
    private var behaviorConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enhancement Behavior")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Toggle("Auto-enhance transcriptions", isOn: $autoEnhance)
                    .toggleStyle(.switch)
                
                if autoEnhance {
                    Toggle("Context-aware enhancement", isOn: $contextAware)
                        .toggleStyle(.switch)
                    
                    if contextAware {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Enhancement will use project context and recent conversations for better results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
                
                Toggle("Save enhancement history", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .disabled(true)
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Enhancement history helps improve future suggestions and context awareness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Trigger Configuration Section
    
    private var triggerConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enhancement Triggers")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Text("Configure when AI enhancement should automatically trigger:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(triggerPatterns, id: \.self) { pattern in
                        HStack {
                            Text(pattern)
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.controlBackgroundColor))
                                )
                            
                            Spacer()
                            
                            Button("Remove") {
                                triggerPatterns.removeAll { $0 == pattern }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        TextField("Add trigger pattern (e.g., @enhance, @help)", text: $newPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            addTriggerPattern()
                        }
                        .buttonStyle(.bordered)
                        .disabled(newPattern.isEmpty)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Common trigger patterns:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        ForEach(["@enhance", "@help", "@context", "@improve"], id: \.self) { pattern in
                            Button(pattern) {
                                if !triggerPatterns.contains(pattern) {
                                    triggerPatterns.append(pattern)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(triggerPatterns.contains(pattern))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canCreateProfile: Bool {
        !triggerPatterns.isEmpty
    }
    
    private func loadSmartDefaults() {
        enhancementProfile = smartDefaults.suggestedEnhancementProfile
        selectedModel = smartDefaults.suggestedModel
        
        // Add default trigger patterns
        if triggerPatterns.isEmpty {
            triggerPatterns = ["@enhance", "@help"]
        }
    }
    
    private func addTriggerPattern() {
        guard !newPattern.isEmpty else { return }
        
        if !triggerPatterns.contains(newPattern) {
            triggerPatterns.append(newPattern)
            newPattern = ""
        }
    }
    
    private func createEnhancementProfile() {
        guard canCreateProfile else { return }
        
        isCreating = true
        
        Task {
            do {
                // Create enhancement profile with backend
                // This would integrate with the new backend architecture
                
                // For now, just save to UserDefaults
                let profileData = EnhancementProfileData(
                    profile: enhancementProfile,
                    model: selectedModel,
                    autoEnhance: autoEnhance,
                    contextAware: contextAware,
                    triggerPatterns: triggerPatterns
                )
                
                saveProfileToDefaults(profileData)
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func saveProfileToDefaults(_ profile: EnhancementProfileData) {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(profile.profile.rawValue, forKey: "EnhancementProfile.Type")
        userDefaults.set(profile.model.rawValue, forKey: "EnhancementProfile.Model")
        userDefaults.set(profile.autoEnhance, forKey: "EnhancementProfile.AutoEnhance")
        userDefaults.set(profile.contextAware, forKey: "EnhancementProfile.ContextAware")
        userDefaults.set(profile.triggerPatterns, forKey: "EnhancementProfile.Triggers")
    }
}

// MARK: - Supporting Views

struct ModelSelectionCard: View {
    let model: ModelSuggestion
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.rawValue)
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
                    }
                    
                    Text(getModelDescription(model))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(getModelPerformance(model))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getModelDescription(_ model: ModelSuggestion) -> String {
        switch model {
        case .whisperTiny:
            return "Fastest, lowest accuracy"
        case .whisperSmall:
            return "Fast, good accuracy"
        case .whisperMedium:
            return "Balanced speed and accuracy"
        case .whisperLarge:
            return "Highest accuracy, slower"
        }
    }
    
    private func getModelPerformance(_ model: ModelSuggestion) -> String {
        switch model {
        case .whisperTiny:
            return "~1GB RAM, ~0.5s latency"
        case .whisperSmall:
            return "~2GB RAM, ~1s latency"
        case .whisperMedium:
            return "~4GB RAM, ~2s latency"
        case .whisperLarge:
            return "~8GB RAM, ~4s latency"
        }
    }
}

// MARK: - Supporting Types

struct EnhancementProfileData {
    let profile: EnhancementProfileSuggestion
    let model: ModelSuggestion
    let autoEnhance: Bool
    let contextAware: Bool
    let triggerPatterns: [String]
}

#Preview {
    EnhancementSetupWorkflow()
}
