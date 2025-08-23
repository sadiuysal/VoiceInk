import SwiftUI

struct RecordingSetupWorkflow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var selectedModel: ModelSuggestion = .whisperMedium
    @State private var recordingQuality: RecordingQuality = .high
    @State private var autoEnhance = true
    @State private var saveToHistory = true
    @State private var selectedHotkey: HotkeySuggestion = .commandShiftR
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
                        
                        Text("Recording Setup")
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Save Configuration") {
                            saveRecordingConfiguration()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Text("Configure your recording preferences and transcription settings")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                
                // Progress Steps
                ProgressStepsView(
                    steps: ["Model", "Quality", "Behavior", "Hotkey"],
                    currentStep: 1
                )
                .padding(.horizontal, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Model Selection
                        modelSelectionSection
                        
                        // Recording Quality
                        recordingQualitySection
                        
                        // Behavior Configuration
                        behaviorConfigurationSection
                        
                        // Hotkey Configuration
                        hotkeyConfigurationSection
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
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Performance")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("The selected model will be used for all transcriptions. Consider your device's performance and accuracy needs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
    
    // MARK: - Recording Quality Section
    
    private var recordingQualitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recording Quality")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ForEach(RecordingQuality.allCases, id: \.self) { quality in
                    QualitySelectionCard(
                        quality: quality,
                        isSelected: recordingQuality == quality,
                        onSelect: { recordingQuality = quality }
                    )
                }
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality vs. Performance")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Higher quality provides better transcription accuracy but uses more storage and processing power.")
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
            Text("Recording Behavior")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Toggle("Auto-enhance transcriptions", isOn: $autoEnhance)
                    .toggleStyle(.switch)
                
                if autoEnhance {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Transcriptions will be automatically enhanced using AI for better clarity and formatting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                
                Toggle("Save to history", isOn: $saveToHistory)
                    .toggleStyle(.switch)
                
                if saveToHistory {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("All transcriptions will be saved to your history for future reference and context")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Toggle("Show recording indicator", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .disabled(true)
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.purple)
                    
                    Text("Visual indicator shows when recording is active and transcription is in progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Hotkey Configuration Section
    
    private var hotkeyConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recording Hotkey")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Text("Choose a hotkey to start/stop recording:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(HotkeySuggestion.allCases, id: \.self) { hotkey in
                        HotkeySelectionCard(
                            hotkey: hotkey,
                            isSelected: selectedHotkey == hotkey,
                            isRecommended: hotkey == smartDefaults.suggestedHotkey,
                            onSelect: { selectedHotkey = hotkey }
                        )
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("The selected hotkey will be used to start and stop recording from anywhere in the system")
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
    }
    
    // MARK: - Helper Methods
    
    private func loadSmartDefaults() {
        selectedModel = smartDefaults.suggestedModel
        selectedHotkey = smartDefaults.suggestedHotkey
    }
    
    private func saveRecordingConfiguration() {
        isCreating = true
        
        Task {
            do {
                // Save configuration to UserDefaults and backend
                let config = RecordingConfiguration(
                    model: selectedModel,
                    quality: recordingQuality,
                    autoEnhance: autoEnhance,
                    saveToHistory: saveToHistory,
                    hotkey: selectedHotkey
                )
                
                saveConfigurationToDefaults(config)
                
                // Update backend configuration
                // This would integrate with the new backend architecture
                
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
    
    private func saveConfigurationToDefaults(_ config: RecordingConfiguration) {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(config.model.rawValue, forKey: "RecordingConfig.Model")
        userDefaults.set(config.quality.rawValue, forKey: "RecordingConfig.Quality")
        userDefaults.set(config.autoEnhance, forKey: "RecordingConfig.AutoEnhance")
        userDefaults.set(config.saveToHistory, forKey: "RecordingConfig.SaveToHistory")
        userDefaults.set(config.hotkey.rawValue, forKey: "RecordingConfig.Hotkey")
    }
}

// MARK: - Supporting Views

struct QualitySelectionCard: View {
    let quality: RecordingQuality
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(getQualityDescription(quality))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(getQualityImpact(quality))
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
    
    private func getQualityDescription(_ quality: RecordingQuality) -> String {
        switch quality {
        case .low:
            return "Basic quality, fast processing"
        case .medium:
            return "Good quality, balanced performance"
        case .high:
            return "High quality, best accuracy"
        }
    }
    
    private func getQualityImpact(_ quality: RecordingQuality) -> String {
        switch quality {
        case .low:
            return "~0.5MB/min, ~0.1s latency"
        case .medium:
            return "~1MB/min, ~0.2s latency"
        case .high:
            return "~2MB/min, ~0.3s latency"
        }
    }
}

struct HotkeySelectionCard: View {
    let hotkey: HotkeySuggestion
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(hotkey.rawValue)
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
                    
                    Text(getHotkeyDescription(hotkey))
                        .font(.caption)
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
    
    private func getHotkeyDescription(_ hotkey: HotkeySuggestion) -> String {
        switch hotkey {
        case .commandShiftR:
            return "Easy to remember, rarely conflicts"
        case .commandShiftT:
            return "Intuitive for transcription"
        case .commandShiftV:
            return "Quick access from anywhere"
        case .commandShiftM:
            return "Easy thumb reach"
        case .commandOptionR:
            return "Alternative option"
        case .commandOptionT:
            return "Alternative option"
        }
    }
}

// MARK: - Supporting Types

struct RecordingConfiguration {
    let model: ModelSuggestion
    let quality: RecordingQuality
    let autoEnhance: Bool
    let saveToHistory: Bool
    let hotkey: HotkeySuggestion
}

#Preview {
    RecordingSetupWorkflow()
}
