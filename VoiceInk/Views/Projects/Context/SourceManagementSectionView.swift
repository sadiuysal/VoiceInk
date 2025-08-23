import SwiftUI
import SwiftData
import os

struct SourceManagementSectionView: View {
    let project: Project
    @StateObject private var contextStore = ContextIndexStore.shared

    @Environment(\.modelContext) private var modelContext
    @Query private var allSources: [ContextSource]
    
    @State private var selectedMode: String = "fullRepository"
    @State private var customPatterns = CustomPatterns()
    @State private var showingCopyFeedback = false
    @State private var copyFeedbackMessage = ""
    @State private var showingAdvancedSettings = false
    @State private var showingAddSourceSheet = false
    @State private var editingSource: ContextSource?
    @State private var showingDeleteAlert = false
    @State private var sourceToDelete: ContextSource?
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "SourceManagementSection")
    
    private var projectSources: [ContextSource] {
        allSources.filter { $0.project?.id == project.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Header
                sectionHeader
                
                // Repository Information
                if let rootPath = project.rootPath {
                    repositoryInformation(rootPath: rootPath)
                } else {
                    noRepositoryView
                }
                
                // Context Sources Management
                contextSourcesSection
                
                // GitIngest Integration
                if UserDefaults.standard.useGitIngest && project.rootPath != nil {
                    gitIngestSection
                }
                
                // Source Files Management
                sourceFilesSection
                
                // Manual Notes
                manualNotesSection
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .overlay(alignment: .topTrailing) {
            copyFeedbackOverlay
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Management")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Add and manage context sources to gather project information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Add Source") {
                    showingAddSourceSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Repository Information
    
    private func repositoryInformation(rootPath: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repository Information")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                RepoInfoRow(label: "Path", value: rootPath, icon: "folder")
                RepoInfoRow(label: "Name", value: URL(fileURLWithPath: rootPath).lastPathComponent, icon: "tag")
                
                if let branch = project.currentBranch {
                    RepoInfoRow(label: "Branch", value: branch, icon: "git.branch")
                }
                
                if let remote = project.remoteOrigin {
                    RepoInfoRow(label: "Remote", value: remote, icon: "globe")
                }
                
                let documents = contextStore.getIndexedDocuments(for: rootPath)
                RepoInfoRow(label: "Indexed Documents", value: "\(documents.count)", icon: "doc.text")
                
                // TODO: Implement with new backend architecture
                RepoInfoRow(label: "Indexed Files", value: "0", icon: "doc.badge.gearshape")
                
                let segments = contextStore.getAllSegments(for: rootPath, minScore: 1)
                RepoInfoRow(label: "Total Segments", value: "\(segments.count)", icon: "list.bullet")
                
                if UserDefaults.standard.useGitIngest {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("GitIngest Sync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if contextStore.isGitIngestSyncing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Syncing...")
                                    .font(.caption)
                            }
                        } else if let lastSync = contextStore.lastGitIngestSyncAt {
                            Text(lastSync, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
            
            // Repository Actions
            VStack(spacing: 12) {
                Text("Repository Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ActionButton(
                        icon: "arrow.clockwise",
                        title: "Reindex Repository",
                        subtitle: "Refresh all indexed content",
                        color: .blue,
                        isDisabled: contextStore.isIndexing
                    ) {
                        reindexRepository()
                    }
                    
                    ActionButton(
                        icon: "folder.badge.gearshape",
                        title: "Set Custom Root",
                        subtitle: "Change project root path",
                        color: .green
                    ) {
                        setCustomProjectRoot()
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: "Clear Index",
                        subtitle: "Remove all indexed data",
                        color: .red
                    ) {
                        clearRepositoryIndex()
                    }
                }
            }
        }
    }
    
    private var noRepositoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Repository Path Set")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Set a repository path to enable source management and context analysis.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button("Set Repository Path") {
                setCustomProjectRoot()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - GitIngest Section
    
    private var gitIngestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Sources")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Create context sources from Git repositories or manual notes to gather project context.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                // Source Type Selection
                HStack {
                    Text("Source Type")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Picker("Type", selection: $selectedMode) {
                        Text("Git Repository").tag("fullRepository")
                        Text("Custom Filtered").tag("customFiltered")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                // Custom patterns for filtered mode
                if selectedMode == "customFiltered" {
                    customPatternsConfiguration
                }
                
                // Source Creation Actions
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ActionButton(
                        icon: "plus.circle",
                        title: "Add Git Source",
                        subtitle: "Create source from repository",
                        color: .blue,
                        isDisabled: contextStore.isGitIngestSyncing
                    ) {
                        showingAddSourceSheet = true
                    }
                    
                    ActionButton(
                        icon: "wand.and.stars",
                        title: "Auto-Detect",
                        subtitle: "Find existing sources",
                        color: .purple,
                        isDisabled: false // TODO: Implement with new backend architecture
                    ) {
                        autoDetectSources()
                    }
                }
                
                if contextStore.isGitIngestSyncing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Creating source...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
        }
    }
    
    private var customPatternsConfiguration: some View {
        VStack(spacing: 12) {
            // Include patterns
            VStack(alignment: .leading, spacing: 6) {
                Text("Include Patterns")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("e.g., *.swift, *.md, README*", text: Binding(
                    get: { customPatterns.include.joined(separator: ", ") },
                    set: { customPatterns.include = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            // Exclude patterns
            VStack(alignment: .leading, spacing: 6) {
                Text("Exclude Patterns")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("e.g., node_modules/*, .git/*, *.log", text: Binding(
                    get: { customPatterns.exclude.joined(separator: ", ") },
                    set: { customPatterns.exclude = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            // Max file size
            HStack {
                Text("Max File Size")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Slider(
                    value: Binding(
                        get: { Double(customPatterns.maxFileSize) },
                        set: { customPatterns.maxFileSize = Int($0) }
                    ),
                    in: 1024...204800,
                    step: 1024
                )
                .frame(width: 120)
                
                Text("\(customPatterns.maxFileSize / 1024)KB")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 50)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.quaternarySystemFill))
        )
    }
    
    // MARK: - Source Files Section
    
    private var sourceFilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Source Files & Patterns")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Configure which files and patterns to include in context analysis.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if showingAdvancedSettings {
                VStack(spacing: 12) {
                    // File type filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Included File Types")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["swift", "md", "txt", "json", "yaml", "toml"], id: \.self) { type in
                                    FileTypeChip(type: type, isSelected: true) {
                                        // TODO: Toggle file type inclusion
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Exclusion patterns
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exclusion Patterns")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        TextField("Add patterns to exclude (e.g., *.log, temp/*, build/*)", text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Context Sources Section
    
    private var contextSourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Context Sources")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Add Source") {
                    showingAddSourceSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Manage repositories, manual notes, and documentation sources for this project.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if projectSources.isEmpty {
                emptySourcesView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(projectSources) { source in
                        ContextSourceRowView(
                            source: source,
                            onEdit: { editingSource = source },
                            onDelete: { 
                                sourceToDelete = source
                                showingDeleteAlert = true
                            },
                            onSync: { syncSource(source) }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSourceSheet) {
            AddContextSourceSheet(project: project, modelContext: modelContext)
        }
        .sheet(item: $editingSource) { source in
            EditContextSourceSheet(source: source, modelContext: modelContext)
        }
        .alert("Delete Source", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { 
                sourceToDelete = nil 
            }
            Button("Delete", role: .destructive) {
                if let source = sourceToDelete {
                    deleteSource(source)
                }
                sourceToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this context source? This action cannot be undone.")
        }
    }
    
    private var emptySourcesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Context Sources")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Add Git repositories, manual notes, or documentation sources to enhance your project context.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button("Add Your First Source") {
                showingAddSourceSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - Manual Notes Section
    
    private var manualNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manual Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Add Note") {
                    // TODO: Show add manual note dialog
                    copyFeedbackMessage = "Manual notes feature coming soon!"
                    showCopyFeedback()
                }
                .buttonStyle(.bordered)
            }
            
            Text("Add custom notes and documentation to enhance project context.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Manual notes list placeholder
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Manual Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Add custom notes to supplement auto-detected context")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Copy Feedback Overlay
    
    private var copyFeedbackOverlay: some View {
        Group {
            if showingCopyFeedback {
                Text(copyFeedbackMessage)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundColor(.white)
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showingCopyFeedback = false
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func reindexRepository() {
        FilesystemContextService.shared.refreshIfNeeded()
        copyFeedbackMessage = "Repository reindexing started!"
        showCopyFeedback()
    }
    
    private func setCustomProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            // TODO: Update project root path
            UserDefaults.standard.manualProjectRootPath = url.path
            FilesystemContextService.shared.refreshIfNeeded()
            
            copyFeedbackMessage = "Project root updated!"
            showCopyFeedback()
        }
    }
    
    private func clearRepositoryIndex() {
        guard let rootPath = project.rootPath else { return }
        contextStore.clearIndex(for: rootPath)
        
        copyFeedbackMessage = "Repository index cleared!"
        showCopyFeedback()
    }
    
    // MARK: - Helper Functions
    
    // TODO: Implement with new backend architecture
    private func autoDetectSources() {
        // Placeholder for new backend integration
        logger.info("Auto-detection not yet implemented with new backend")
    }
    
    // TODO: Implement with new backend architecture
    private func performFullRepoSync() {
        // Placeholder for new backend integration
        logger.info("Repository sync not yet implemented with new backend")
    }
    
    // TODO: Implement with new backend architecture
    private func generateAndCopyGitIngestContext() {
        // Placeholder for new backend integration
        logger.info("GitIngest context generation not yet implemented with new backend")
    }
    
    private func showCopyFeedback() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
        }
    }
    
    // MARK: - Context Source Management
    
    private func syncSource(_ source: ContextSource) {
        Task {
            do {
                // TODO: Implement with new backend architecture
                await MainActor.run {
                    copyFeedbackMessage = "Source '\(source.name)' sync not yet implemented with new backend"
                    showCopyFeedback()
                }
            } catch {
                await MainActor.run {
                    copyFeedbackMessage = "Sync failed: \(error.localizedDescription)"
                    showCopyFeedback()
                }
                logger.error("Source sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteSource(_ source: ContextSource) {
        modelContext.delete(source)
        
        do {
            try modelContext.save()
            copyFeedbackMessage = "Source '\(source.name)' deleted successfully!"
            showCopyFeedback()
        } catch {
            copyFeedbackMessage = "Failed to delete source: \(error.localizedDescription)"
            showCopyFeedback()
            logger.error("Failed to delete source: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct ContextSourceRowView: View {
    let source: ContextSource
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSync: () -> Void

    
    private var statusColor: Color {
        switch source.syncStatus {
        case "completed": return .green
        case "syncing": return .blue
        case "error": return .red
        default: return .secondary
        }
    }
    
    private var statusIcon: String {
        switch source.syncStatus {
        case "completed": return "checkmark.circle.fill"
        case "syncing": return "arrow.triangle.2.circlepath"
        case "error": return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Source type icon and name
                HStack(spacing: 12) {
                    Image(systemName: source.sourceType.icon)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(source.sourceType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Text(source.syncStatus.capitalized)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }
            
            // Description and path
            if !source.sourceDescription.isEmpty {
                Text(source.sourceDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let sourcePath = source.sourcePath {
                Text(sourcePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Error message
            if let errorMessage = source.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
            
            // Action buttons
            HStack {
                Button("Sync") {
                    onSync()
                }
                .buttonStyle(.bordered)
                .disabled(source.syncStatus == "syncing")
                
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                // Last sync time
                if let lastSync = source.lastSyncAt {
                    Text("Last sync: \(lastSync, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct AddContextSourceSheet: View {
    let project: Project
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceType: ContextSourceType = .gitIngest
    @State private var sourceName = ""
    @State private var sourceDescription = ""
    @State private var sourcePath = ""
    @State private var gitIngestConfig = GitIngestConfiguration(repositoryPath: "")
    @State private var manualNotesConfig = ManualNotesConfiguration()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Source Name", text: $sourceName)
                    TextField("Description (optional)", text: $sourceDescription)
                    
                    Picker("Source Type", selection: $sourceType) {
                        ForEach(ContextSourceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section("Configuration") {
                    switch sourceType {
                    case .gitIngest:
                        gitIngestConfigSection
                    case .manualNotes:
                        manualNotesConfigSection
                    default:
                        Text("Configuration options for \(sourceType.displayName) coming soon")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Context Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSource()
                    }
                    .disabled(sourceName.isEmpty)
                }
            }
        }
    }
    
    private var gitIngestConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Repository Path", text: $sourcePath)
                .onChange(of: sourcePath) { _, newValue in
                    gitIngestConfig = GitIngestConfiguration(repositoryPath: newValue)
                }
        }
    }
    
    private var manualNotesConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Notes Directory", text: $sourcePath)
        }
    }
    
    private func addSource() {
        let source = ContextSource(
            name: sourceName,
            sourceDescription: sourceDescription,
            sourceType: sourceType,
            sourcePath: sourcePath.isEmpty ? nil : sourcePath,
            project: project
        )
        
        // Set configuration based on source type
        do {
            switch sourceType {
            case .gitIngest:
                try source.setConfiguration(gitIngestConfig)
            case .manualNotes:
                try source.setConfiguration(manualNotesConfig)
            default:
                break
            }
        } catch {
            // Handle configuration error
            print("Failed to set configuration: \(error)")
        }
        
        modelContext.insert(source)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save source: \(error)")
        }
    }
}

struct EditContextSourceSheet: View {
    let source: ContextSource
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceName = ""
    @State private var sourceDescription = ""
    @State private var sourcePath = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Source Name", text: $sourceName)
                    TextField("Description (optional)", text: $sourceDescription)
                    
                    HStack {
                        Text("Source Type")
                        Spacer()
                        Text(source.sourceType.displayName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Configuration") {
                    TextField("Source Path", text: $sourcePath)
                }
                
                Section("Status") {
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        Text(source.syncStatus.capitalized)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = source.lastSyncAt {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Context Source")
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
                    .disabled(sourceName.isEmpty)
                }
            }
        }
        .onAppear {
            loadSourceData()
        }
    }
    
    private func loadSourceData() {
        sourceName = source.name
        sourceDescription = source.sourceDescription
        sourcePath = source.sourcePath ?? ""
    }
    
    private func saveChanges() {
        source.name = sourceName
        source.sourceDescription = sourceDescription
        source.sourcePath = sourcePath.isEmpty ? nil : sourcePath
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save changes: \(error)")
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isDisabled ? .secondary : color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

struct FileTypeChip: View {
    let type: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(".\(type)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentColor : Color(.quaternarySystemFill))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types

struct CustomPatterns {
    var include: [String] = []
    var exclude: [String] = []
    var maxFileSize: Int = 16384 // 16KB default
}

// MARK: - Supporting Views

struct RepoInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

#Preview {
    SourceManagementSectionView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}