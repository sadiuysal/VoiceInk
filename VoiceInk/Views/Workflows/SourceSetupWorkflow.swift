import SwiftUI
import SwiftData

struct SourceSetupWorkflow: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    
    @State private var selectedSourceType: SourceType = .gitRepository
    @State private var sourceName = ""
    @State private var sourcePath = ""
    @State private var sourceURL = ""
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
                        
                        Text("Add Context Source")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Add Source") {
                            addSource()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddSource)
                    }
                    
                    Text("Add a new context source to enhance your project's AI capabilities")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                
                // Progress Steps
                ProgressStepsView(
                    steps: ["Type", "Configuration", "Validation"],
                    currentStep: 1
                )
                .padding(.horizontal, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Source Type Selection
                        sourceTypeSection
                        
                        // Source Configuration
                        sourceConfigurationSection
                        
                        // Validation and Preview
                        validationSection
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            setupDefaultValues()
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
    
    // MARK: - Source Type Section
    
    private var sourceTypeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Source Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(SourceType.allCases, id: \.self) { sourceType in
                    SourceTypeCard(
                        sourceType: sourceType,
                        isSelected: selectedSourceType == sourceType,
                        onSelect: { selectedSourceType = sourceType }
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Name")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    TextField("Enter a name for this source", text: $sourceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                switch selectedSourceType {
                case .gitRepository:
                    gitRepositoryConfiguration
                case .webCrawl:
                    webCrawlConfiguration
                case .manualFiles:
                    manualFilesConfiguration
                case .chatStream:
                    chatStreamConfiguration
                }
            }
        }
    }
    
    private var gitRepositoryConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository Path")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Path to Git repository", text: $sourcePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Browse") {
                        selectRepositoryPath()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration Options")
                    .font(.body)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include submodules", isOn: .constant(false))
                        .toggleStyle(.switch)
                    
                    Toggle("Include ignored files", isOn: .constant(false))
                        .toggleStyle(.switch)
                    
                    Toggle("Track file changes", isOn: .constant(true))
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    private var webCrawlConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Starting URL")
                    .font(.body)
                    .fontWeight(.medium)
                
                TextField("https://example.com", text: $sourceURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Crawl Options")
                    .font(.body)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Depth")
                        Spacer()
                        Text("2")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Pages")
                        Spacer()
                        Text("100")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Follow external links", isOn: .constant(false))
                        .toggleStyle(.switch)
                    
                    Toggle("Respect robots.txt", isOn: .constant(true))
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    private var manualFilesConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Files Directory")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Path to documentation files", text: $sourcePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Browse") {
                        selectFilesDirectory()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("File Types")
                    .font(.body)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Markdown files (.md)", isOn: .constant(true))
                        .toggleStyle(.switch)
                    
                    Toggle("JSON files (.json)", isOn: .constant(true))
                        .toggleStyle(.switch)
                    
                    Toggle("Text files (.txt)", isOn: .constant(false))
                        .toggleStyle(.switch)
                    
                    Toggle("Monitor for changes", isOn: .constant(true))
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    private var chatStreamConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Application")
                    .font(.body)
                    .fontWeight(.medium)
                
                Picker("Application", selection: .constant("Cursor")) {
                    Text("Cursor").tag("Cursor")
                    Text("Claude Code").tag("Claude Code")
                    Text("Terminal").tag("Terminal")
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Stream Options")
                    .font(.body)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Messages")
                        Spacer()
                        Text("20")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Bytes")
                        Spacer()
                        Text("16KB")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Auto-enhance context", isOn: .constant(true))
                        .toggleStyle(.switch)
                    
                    Toggle("Real-time updates", isOn: .constant(true))
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    // MARK: - Validation Section
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Validation & Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("VoiceInk will validate your source configuration and provide a preview of what will be indexed")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                
                if canAddSource {
                    Button("Validate Configuration") {
                        validateConfiguration()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canAddSource: Bool {
        !sourceName.isEmpty && 
        (selectedSourceType == .gitRepository && !sourcePath.isEmpty ||
         selectedSourceType == .webCrawl && !sourceURL.isEmpty ||
         selectedSourceType == .manualFiles && !sourcePath.isEmpty ||
         selectedSourceType == .chatStream)
    }
    
    private func setupDefaultValues() {
        sourceName = "\(selectedSourceType.displayName) Source"
    }
    
    private func selectRepositoryPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select Git repository directory"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
            // Auto-detect if it's a Git repository
            let gitPath = (sourcePath as NSString).appendingPathComponent(".git")
            if !FileManager.default.fileExists(atPath: gitPath) {
                // Show warning that this might not be a Git repository
            }
        }
    }
    
    private func selectFilesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select documentation files directory"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
        }
    }
    
    private func validateConfiguration() {
        // Validate the source configuration
        // This would integrate with the backend validation
    }
    
    private func addSource() {
        guard canAddSource else { return }
        
        isCreating = true
        
        Task {
            do {
                guard let projectRegistry = backendRegistry.projectRegistry else {
                    throw SourceCreationError.backendNotReady
                }
                
                // Create source configuration based on type
                let config = createSourceConfiguration()
                
                // Add source to project via backend
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
    
    private func createSourceConfiguration() -> [String: Any] {
        var config: [String: Any] = [
            "name": sourceName,
            "type": selectedSourceType.rawValue
        ]
        
        switch selectedSourceType {
        case .gitRepository:
            config["path"] = sourcePath
            config["includeSubmodules"] = false
            config["includeIgnored"] = false
            config["trackChanges"] = true
        case .webCrawl:
            config["url"] = sourceURL
            config["maxDepth"] = 2
            config["maxPages"] = 100
            config["followExternal"] = false
            config["respectRobots"] = true
        case .manualFiles:
            config["path"] = sourcePath
            config["fileTypes"] = [".md", ".json"]
            config["monitorChanges"] = true
        case .chatStream:
            config["application"] = "Cursor"
            config["maxMessages"] = 20
            config["maxBytes"] = 16384
            config["autoEnhance"] = true
            config["realTime"] = true
        }
        
        return config
    }
}

// MARK: - Supporting Views

struct SourceTypeCard: View {
    let sourceType: SourceType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: sourceType.icon)
                    .font(.title)
                    .foregroundColor(sourceType.color)
                
                Text(sourceType.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(sourceType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? sourceType.color.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? sourceType.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types

enum SourceType: String, CaseIterable {
    case gitRepository = "git-repository"
    case webCrawl = "web-crawl"
    case manualFiles = "manual-files"
    case chatStream = "chat-stream"
    
    var displayName: String {
        switch self {
        case .gitRepository:
            return "Git Repository"
        case .webCrawl:
            return "Web Crawl"
        case .manualFiles:
            return "Manual Files"
        case .chatStream:
            return "Chat Stream"
        }
    }
    
    var description: String {
        switch self {
        case .gitRepository:
            return "Source code and documentation from Git repositories"
        case .webCrawl:
            return "Web pages and documentation from URLs"
        case .manualFiles:
            return "Local documentation and configuration files"
        case .chatStream:
            return "Real-time chat conversations and context"
        }
    }
    
    var icon: String {
        switch self {
        case .gitRepository:
            return "git.branch"
        case .webCrawl:
            return "globe"
        case .manualFiles:
            return "doc.text"
        case .chatStream:
            return "message"
        }
    }
    
    var color: Color {
        switch self {
        case .gitRepository:
            return .orange
        case .webCrawl:
            return .blue
        case .manualFiles:
            return .green
        case .chatStream:
            return .purple
        }
    }
}

enum SourceCreationError: LocalizedError {
    case backendNotReady
    
    var errorDescription: String? {
        switch self {
        case .backendNotReady:
            return "Backend services are not ready. Please try again in a moment."
        }
    }
}

#Preview {
    // Create a mock project for preview
    let mockProject = Project(
        name: "Preview Project",
        projectDescription: "A sample project for preview",
        rootPath: "/tmp/preview"
    )
    SourceSetupWorkflow(project: mockProject)
}
