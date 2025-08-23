import SwiftUI
import SwiftData
import os

// MARK: - Supporting Types

enum GitIngestMode: String, CaseIterable {
    case fullRepository = "fullRepository"
    case documentationOnly = "documentationOnly"
    case codeOnly = "codeOnly"
    case projectStructure = "projectStructure"
    case customFiltered = "customFiltered"
}

// MARK: - Create Context Pack Sheet

struct CreateContextPackSheet: View {
    let allProjects: [Project]
    let allSources: [ContextSource]
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var packName = ""
    @State private var packDescription = ""
    @State private var selectedSourceIds: Set<UUID> = []
    @State private var selectedProjectIds: Set<UUID> = []
    @State private var isActive = true
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "CreateContextPackSheet")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Context Pack")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a new context pack that can include sources from multiple projects")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Basic Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Basic Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter pack name", text: $packName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter pack description", text: $packDescription, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            
                            Toggle("Active", isOn: $isActive)
                                .font(.subheadline)
                        }
                        
                        Divider()
                        
                        // Source Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Sources")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Select sources to include in this context pack")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if allSources.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "folder.badge.gearshape")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Sources Available")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Create sources first to add them to context packs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.controlBackgroundColor))
                                )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(allSources) { source in
                                        SourceSelectionRow(
                                            source: source,
                                            allProjects: allProjects,
                                            isSelected: selectedSourceIds.contains(source.id),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    selectedSourceIds.insert(source.id)
                                                } else {
                                                    selectedSourceIds.remove(source.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Project Association
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project Association")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Associate this pack with specific projects (optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if allProjects.isEmpty {
                                Text("No projects available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(allProjects) { project in
                                        ProjectSelectionRow(
                                            project: project,
                                            isSelected: selectedProjectIds.contains(project.id),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    selectedProjectIds.insert(project.id)
                                                } else {
                                                    selectedProjectIds.remove(project.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Create Context Pack")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createPack()
                }
                .disabled(packName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func createPack() {
        let pack = ContextPack(
            name: packName.trimmingCharacters(in: .whitespacesAndNewlines),
            packDescription: packDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceIds: Array(selectedSourceIds),
            isActive: isActive
        )
        
        // Associate with selected projects
        for projectId in selectedProjectIds {
            if let project = allProjects.first(where: { $0.id == projectId }) {
                pack.project = project
                break // ContextPack can only have one project, but we'll use the first selected
            }
        }
        
        modelContext.insert(pack)
        
        do {
            try modelContext.save()
            logger.info("Created context pack: \(pack.name)")
            dismiss()
        } catch {
            logger.error("Failed to create context pack: \(error)")
        }
    }
}

// MARK: - Edit Context Pack Sheet

struct EditContextPackSheet: View {
    let pack: ContextPack
    let allProjects: [Project]
    let allSources: [ContextSource]
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var packName: String
    @State private var packDescription: String
    @State private var selectedSourceIds: Set<UUID>
    @State private var selectedProjectIds: Set<UUID>
    @State private var isActive: Bool
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "EditContextPackSheet")
    
    init(pack: ContextPack, allProjects: [Project], allSources: [ContextSource], modelContext: ModelContext) {
        self.pack = pack
        self.allProjects = allProjects
        self.allSources = allSources
        self.modelContext = modelContext
        
        // Initialize state
        _packName = State(initialValue: pack.name)
        _packDescription = State(initialValue: pack.packDescription)
        _selectedSourceIds = State(initialValue: Set(pack.sourceIds))
        _isActive = State(initialValue: pack.isActive)
        
        // Initialize project selection
        if let project = pack.project {
            _selectedProjectIds = State(initialValue: [project.id])
        } else {
            _selectedProjectIds = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit Context Pack")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Modify the context pack configuration and source selection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Basic Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Basic Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter pack name", text: $packName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter pack description", text: $packDescription, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            
                            Toggle("Active", isOn: $isActive)
                                .font(.subheadline)
                        }
                        
                        Divider()
                        
                        // Source Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Sources")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Select sources to include in this context pack")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if allSources.isEmpty {
                                Text("No sources available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(allSources) { source in
                                        SourceSelectionRow(
                                            source: source,
                                            allProjects: allProjects,
                                            isSelected: selectedSourceIds.contains(source.id),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    selectedSourceIds.insert(source.id)
                                                } else {
                                                    selectedSourceIds.remove(source.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Project Association
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project Association")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Associate this pack with specific projects (optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if allProjects.isEmpty {
                                Text("No projects available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(allProjects) { project in
                                        ProjectSelectionRow(
                                            project: project,
                                            isSelected: selectedProjectIds.contains(project.id),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    selectedProjectIds.removeAll()
                                                    selectedProjectIds.insert(project.id)
                                                } else {
                                                    selectedProjectIds.remove(project.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Edit Context Pack")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(packName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func saveChanges() {
        pack.name = packName.trimmingCharacters(in: .whitespacesAndNewlines)
        pack.packDescription = packDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        pack.sourceIds = Array(selectedSourceIds)
        pack.isActive = isActive
        pack.updateTimestamp()
        
        // Update project association
        if let projectId = selectedProjectIds.first,
           let project = allProjects.first(where: { $0.id == projectId }) {
            pack.project = project
        } else {
            pack.project = nil
        }
        
        do {
            try modelContext.save()
            logger.info("Updated context pack: \(pack.name)")
            dismiss()
        } catch {
            logger.error("Failed to update context pack: \(error)")
        }
    }
}

// MARK: - Create Source Sheet

struct CreateSourceSheet: View {
    let allProjects: [Project]
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var sourceName = ""
    @State private var sourceDescription = ""
    @State private var sourceType: ContextSourceType = .gitIngest
    @State private var sourcePath = ""
    @State private var selectedProjectId: UUID?
    @State private var isEnabled = true
    
    // Git Ingest specific fields
    @State private var gitIngestMode: GitIngestMode = .fullRepository
    @State private var includeSubmodules = false
    @State private var includeGitignored = false
    @State private var customPatterns = ""
    
    // Manual Notes specific fields
    @State private var notesDirectory = ""
    @State private var filePatterns = "*.md,*.txt,*.rst"
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "CreateSourceSheet")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Data Source")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure a new data source for context gathering")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Basic Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Basic Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter source name", text: $sourceName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter source description", text: $sourceDescription, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Source Type")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Source Type", selection: $sourceType) {
                                    ForEach(ContextSourceType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            Toggle("Enabled", isOn: $isEnabled)
                                .font(.subheadline)
                        }
                        
                        Divider()
                        
                        // Project Association
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project Association")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Associate this source with a specific project (optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if allProjects.isEmpty {
                                Text("No projects available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("Project", selection: $selectedProjectId) {
                                    Text("No Project").tag(nil as UUID?)
                                    ForEach(allProjects) { project in
                                        Text(project.name).tag(project.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        Divider()
                        
                        // Source Type Specific Configuration
                        Group {
                            switch sourceType {
                            case .gitIngest:
                                gitIngestConfiguration
                            case .manualNotes:
                                manualNotesConfiguration
                            case .documentation:
                                documentationConfiguration
                            case .markdown:
                                EmptyView()
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Create Data Source")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createSource()
                }
                .disabled(sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private var gitIngestConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Git Repository Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository Path")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Enter repository path", text: $sourcePath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse") {
                        // TODO: Implement file picker
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Mode", selection: $gitIngestMode) {
                    Text("Full Repository").tag(GitIngestMode.fullRepository)
                    Text("Documentation Only").tag(GitIngestMode.documentationOnly)
                    Text("Code Only").tag(GitIngestMode.codeOnly)
                    Text("Project Structure").tag(GitIngestMode.projectStructure)
                    Text("Custom Filtered").tag(GitIngestMode.customFiltered)
                }
                .pickerStyle(.segmented)
            }
            
            Toggle("Include Submodules", isOn: $includeSubmodules)
                .font(.subheadline)
            
            Toggle("Include Gitignored Files", isOn: $includeGitignored)
                .font(.subheadline)
            
            if gitIngestMode == .customFiltered {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom File Patterns")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("*.swift,*.h,*.m", text: $customPatterns)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var manualNotesConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Notes Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes Directory")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Enter notes directory path", text: $notesDirectory)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse") {
                        // TODO: Implement file picker
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("File Patterns")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("*.md,*.txt,*.rst", text: $filePatterns)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var documentationConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documentation Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Documentation Path")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Enter documentation path", text: $sourcePath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse") {
                        // TODO: Implement file picker
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text("Documentation sources will automatically index markdown files, README files, and other documentation formats.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func createSource() {
        let source = ContextSource(
            name: sourceName.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceDescription: sourceDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceType: sourceType,
            sourcePath: sourcePath.isEmpty ? nil : sourcePath,
            isEnabled: isEnabled
        )
        
        // Associate with selected project
        if let projectId = selectedProjectId,
           let project = allProjects.first(where: { $0.id == projectId }) {
            source.project = project
        }
        
        // Set type-specific configuration
        do {
            switch sourceType {
            case .gitIngest:
                let config = GitIngestConfiguration(
                    repositoryPath: sourcePath,
                    preset: .custom,
                    includePatterns: customPatterns.isEmpty ? [] : customPatterns.components(separatedBy: ","),
                    excludePatterns: [],
                    maxFileSize: 1024 * 1024, // 1MB default
                    includeSubmodules: includeSubmodules,
                    branch: nil
                )
                try source.setConfiguration(config)
                
            case .manualNotes:
                let config = ManualNotesConfiguration(
                    notesDirectory: notesDirectory.isEmpty ? sourcePath : notesDirectory,
                    autoSaveEnabled: true,
                    markdownPreviewEnabled: true
                )
                try source.setConfiguration(config)
                
            case .documentation:
                let config = DocumentationConfiguration(
                    documentationPath: sourcePath
                )
                try source.setConfiguration(config)
                
            case .markdown:
                // Handle markdown case if needed
                break
            }
        } catch {
            logger.error("Failed to set source configuration: \(error)")
        }
        
        modelContext.insert(source)
        
        do {
            try modelContext.save()
            logger.info("Created source: \(source.name)")
            dismiss()
        } catch {
            logger.error("Failed to create source: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct SourceSelectionRow: View {
    let source: ContextSource
    let allProjects: [Project]
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Image(systemName: source.sourceType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let project = source.project {
                        Text("Project: \(project.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(source.sourceType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProjectSelectionRow: View {
    let project: Project
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let path = project.rootPath {
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Configuration Models

struct DocumentationConfiguration: Codable {
    let documentationPath: String
    
    init(documentationPath: String) {
        self.documentationPath = documentationPath
    }
}

#Preview {
    CreateContextPackSheet(
        allProjects: [],
        allSources: [],
        modelContext: try! ModelContainer(for: Project.self, ContextSource.self, ContextPack.self).mainContext
    )
}
