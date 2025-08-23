import SwiftUI

struct ProjectSetupWorkflow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var projectName = ""
    @State private var projectPath = ""
    @State private var projectType: ProjectType = .unknown
    @State private var enhancementProfile: EnhancementProfileSuggestion = .balanced
    @State private var autoDetectSources = true
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
                        
                        Text("Project Setup")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Create") {
                            createProject()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreateProject)
                    }
                    
                    Text("Configure your project with intelligent defaults and automatic source detection")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                
                // Progress Steps
                ProgressStepsView(
                    steps: ["Basic Info", "Project Type", "Enhancement", "Sources"],
                    currentStep: 1
                )
                .padding(.horizontal, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Basic Information
                        basicInformationSection
                        
                        // Project Type Selection
                        projectTypeSection
                        
                        // Enhancement Profile
                        enhancementProfileSection
                        
                        // Source Configuration
                        sourceConfigurationSection
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
    
    // MARK: - Basic Information Section
    
    private var basicInformationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Name")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    TextField("Enter project name", text: $projectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: projectName) { _ in
                            updateProjectPath()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Path")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("Project directory path", text: $projectPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Browse") {
                            selectProjectPath()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                if !projectPath.isEmpty {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("Path will be validated and sources will be automatically detected")
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
    }
    
    // MARK: - Project Type Section
    
    private var projectTypeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Project Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ProjectType.allCases, id: \.self) { type in
                    ProjectTypeCard(
                        type: type,
                        isSelected: projectType == type,
                        onSelect: { projectType = type }
                    )
                }
            }
            
            if projectType != .unknown {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Selected: \(projectType.displayName)")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Enhancement Profile Section
    
    private var enhancementProfileSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Enhancement Profile")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                ForEach(EnhancementProfileSuggestion.allCases, id: \.self) { profile in
                    EnhancementProfileCard(
                        profile: profile,
                        isSelected: enhancementProfile == profile,
                        isRecommended: profile == getRecommendedProfile(),
                        onSelect: { enhancementProfile = profile }
                    )
                }
            }
        }
    }
    
    // MARK: - Source Configuration Section
    
    private var sourceConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Source Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Toggle("Auto-detect sources", isOn: $autoDetectSources)
                    .toggleStyle(.switch)
                
                if autoDetectSources {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VoiceInk will automatically detect and configure:")
                            .font(.body)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SourceDetectionRow(
                                title: "Git Repository",
                                description: "Source code, commits, and documentation",
                                isDetected: detectGitRepository()
                            )
                            
                            SourceDetectionRow(
                                title: "Documentation Files",
                                description: "README, docs, and markdown files",
                                isDetected: detectDocumentation()
                            )
                            
                            SourceDetectionRow(
                                title: "Configuration Files",
                                description: "Package files, configs, and manifests",
                                isDetected: detectConfiguration()
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                    )
                } else {
                    Text("Manual source configuration will be available after project creation")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canCreateProject: Bool {
        !projectName.isEmpty && !projectPath.isEmpty && projectType != .unknown
    }
    
    private func loadSmartDefaults() {
        projectName = smartDefaults.suggestedProjectName
        projectPath = smartDefaults.suggestedProjectPath
        enhancementProfile = smartDefaults.suggestedEnhancementProfile
        
        if !projectName.isEmpty {
            updateProjectPath()
        }
    }
    
    private func updateProjectPath() {
        if projectPath.isEmpty && !projectName.isEmpty {
            // Suggest a default path based on project name
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            projectPath = homeDir.appendingPathComponent("Projects").appendingPathComponent(projectName).path
        }
    }
    
    private func selectProjectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select project directory"
        
        if panel.runModal() == .OK, let url = panel.url {
            projectPath = url.path
            // Auto-detect project name from path
            projectName = url.lastPathComponent
        }
    }
    
    private func getRecommendedProfile() -> EnhancementProfileSuggestion {
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
    
    private func detectGitRepository() -> Bool {
        let gitPath = (projectPath as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }
    
    private func detectDocumentation() -> Bool {
        let fileManager = FileManager.default
        let contents = try? fileManager.contentsOfDirectory(atPath: projectPath)
        
        return contents?.contains { fileName in
            fileName.lowercased().contains("readme") ||
            fileName.lowercased().contains("docs") ||
            fileName.hasSuffix(".md")
        } ?? false
    }
    
    private func detectConfiguration() -> Bool {
        let fileManager = FileManager.default
        let contents = try? fileManager.contentsOfDirectory(atPath: projectPath)
        
        return contents?.contains { fileName in
            fileName.hasSuffix(".json") ||
            fileName.hasSuffix(".yaml") ||
            fileName.hasSuffix(".yml") ||
            fileName.hasSuffix(".toml") ||
            fileName.hasSuffix(".lock")
        } ?? false
    }
    
    private func createProject() {
        guard canCreateProject else { return }
        
        isCreating = true
        
        Task {
            do {
                guard let projectRegistry = backendRegistry.projectRegistry else {
                    throw ProjectCreationError.backendNotReady
                }
                
                // Create project with backend
                let project = try await projectRegistry.createProject(
                    name: projectName,
                    description: "\(projectType.displayName) project",
                    rootPath: projectPath,
                    configuration: ProjectConfiguration()
                )
                
                // Configure enhancement profile
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
}

// MARK: - Supporting Views

struct ProgressStepsView: View {
    let steps: [String]
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(index < currentStep ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                    
                    Text(step)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(index < currentStep ? .primary : .secondary)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color.secondary)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                if index < steps.count - 1 {
                    Spacer()
                }
            }
        }
    }
}

struct ProjectTypeCard: View {
    let type: ProjectType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title)
                    .foregroundColor(type.color)
                
                Text(type.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? type.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancementProfileCard: View {
    let profile: EnhancementProfileSuggestion
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
                    }
                    
                    Text(getProfileDescription(profile))
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
    
    private func getProfileDescription(_ profile: EnhancementProfileSuggestion) -> String {
        switch profile {
        case .balanced:
            return "Balanced performance and accuracy for general use"
        case .webDevelopment:
            return "Optimized for web development workflows"
        case .mobileDevelopment:
            return "Tailored for mobile app development"
        case .desktopDevelopment:
            return "Specialized for desktop application development"
        case .codeReview:
            return "Enhanced for code review and analysis"
        case .documentation:
            return "Focused on documentation and writing"
        case .meetingNotes:
            return "Optimized for meeting transcription and notes"
        case .creativeWriting:
            return "Enhanced for creative writing and content creation"
        }
    }
}

struct SourceDetectionRow: View {
    let title: String
    let description: String
    let isDetected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isDetected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDetected ? .green : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDetected {
                Text("Detected")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Supporting Types

extension ProjectType: CaseIterable {
    static var allCases: [ProjectType] {
        [.webApp, .mobileApp, .desktopApp, .library, .documentation, .unknown]
    }
    
    var displayName: String {
        switch self {
        case .webApp: return "Web Application"
        case .mobileApp: return "Mobile Application"
        case .desktopApp: return "Desktop Application"
        case .library: return "Library/Framework"
        case .documentation: return "Documentation"
        case .unknown: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .webApp: return "Web apps, APIs, and frontend projects"
        case .mobileApp: return "iOS, Android, and cross-platform apps"
        case .desktopApp: return "macOS, Windows, and Linux applications"
        case .library: return "Code libraries, frameworks, and SDKs"
        case .documentation: return "Documentation, guides, and tutorials"
        case .unknown: return "Other project types"
        }
    }
    
    var icon: String {
        switch self {
        case .webApp: return "globe"
        case .mobileApp: return "iphone"
        case .desktopApp: return "desktopcomputer"
        case .library: return "cube.box"
        case .documentation: return "doc.text"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .webApp: return .blue
        case .mobileApp: return .green
        case .desktopApp: return .purple
        case .library: return .orange
        case .documentation: return .indigo
        case .unknown: return .gray
        }
    }
}

enum ProjectCreationError: LocalizedError {
    case backendNotReady
    
    var errorDescription: String? {
        switch self {
        case .backendNotReady:
            return "Backend services are not ready. Please try again in a moment."
        }
    }
}

#Preview {
    ProjectSetupWorkflow()
}
