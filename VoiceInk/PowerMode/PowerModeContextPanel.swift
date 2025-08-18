import SwiftUI
import SwiftData
import os

struct PowerModeContextPanel: View {
    @State private var rootURL: URL?
    @State private var selectedProfile: DictionaryProfile?
    @State private var selectedDocument: IndexedDocument?
    @State private var showingProfileCreation = false
    @State private var showingRepositoryManager = false
    @State private var showingCopyFeedback = false
    @State private var newProfileName = ""
    @State private var newProfileDescription = ""
    @State private var selectedTab = 0
    @State private var copyFeedbackMessage = ""
    
    @StateObject private var contextStore = ContextIndexStore.shared
    @StateObject private var gitIngestService = GitIngestService.shared
    @State private var selectedMode: GitIngestService.ContextMode = .fullRepository
    @State private var customPatterns = GitIngestService.GitIngestPatterns()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "PowerModeContextPanel")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            
            if rootURL != nil {
                TabView(selection: $selectedTab) {
                    repositoryManagementTab
                        .tabItem { Label("Repository", systemImage: "folder") }
                        .tag(0)
                    
                    profilesManagementTab
                        .tabItem { Label("Profiles", systemImage: "person.2") }
                        .tag(1)
                    
                    documentsTab
                        .tabItem { Label("Documents", systemImage: "doc.text") }
                        .tag(2)
                    
                    quickActionsTab
                        .tabItem { Label("Actions", systemImage: "bolt") }
                        .tag(3)
                }
                .frame(minHeight: 400)
            } else {
                noProjectView
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear { reload() }
        .sheet(isPresented: $showingProfileCreation) {
            profileCreationSheet
        }
        .sheet(isPresented: $showingRepositoryManager) {
            repositoryManagerSheet
        }
        .overlay(alignment: .topTrailing) {
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
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Project Context Manager")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if UserDefaults.standard.enableContextInspector {
                    Button("Advanced Debugging") {
                        ContextInspectorWindowManager.shared.show()
                    }
                    .font(.caption)
                }
            }
            
            if let root = rootURL {
                HStack {
                    Text(root.lastPathComponent)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    let documents = contextStore.getIndexedDocuments(for: root.path)
                    let profiles = contextStore.getProfiles(for: root.path)
                    Text("\(documents.count) docs • \(profiles.count) profiles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if contextStore.isIndexing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Indexing...")
                                .font(.caption)
                        }
                    }
                }
            } else {
                Text("Comprehensive project context management for repository-aware AI assistance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var repositoryManagementTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let root = rootURL {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repository Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text(root.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Name:")
                            Spacer()
                            Text(root.lastPathComponent)
                                .fontWeight(.medium)
                        }
                        
                        let documents = contextStore.getIndexedDocuments(for: root.path)
                        HStack {
                            Text("Indexed Documents:")
                            Spacer()
                            Text("\(documents.count)")
                                .fontWeight(.medium)
                        }
                        
                        let fileCount = ProjectFileIndexStore.shared.files(for: root.path).count
                        HStack {
                            Text("Indexed Files:")
                            Spacer()
                            Text("\(fileCount)")
                                .fontWeight(.medium)
                        }
                        
                        let segments = contextStore.getAllSegments(for: root.path, minScore: 1)
                        HStack {
                            Text("Total Segments:")
                            Spacer()
                            Text("\(segments.count)")
                                .fontWeight(.medium)
                        }
                        
                        if UserDefaults.standard.useGitIngest {
                            HStack {
                                Text("GitIngest Sync:")
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
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repository Actions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 8) {
                        Button("Reindex Repository") {
                            reindex()
                        }
                        .disabled(contextStore.isIndexing)
                        .frame(maxWidth: .infinity)
                        
                        Button("Set Custom Project Root") {
                            setCustomProjectRoot()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("Clear Repository Index") {
                            clearIndex()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var profilesManagementTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Dictionary Profiles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Create Profile") {
                    showingProfileCreation = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Profiles help organize project context for specific coding tasks. Each profile contains pinned segments and custom terms that create focused dictionaries for AI assistance.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let root = rootURL {
                let profiles = contextStore.getProfiles(for: root.path)
                
                if profiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.6))
                        
                        Text("No profiles created yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Create your first profile to organize project context for specific coding tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(profiles, id: \.id, selection: $selectedProfile) { profile in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(profile.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(profile.pinnedSegmentIDs.count) pinned")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !profile.profileDescription.isEmpty {
                                Text(profile.profileDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Text("Modified: \(profile.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let profile = selectedProfile {
                        HStack {
                            Button("Export Dictionary") {
                                exportDictionary(for: profile)
                            }
                            
                            Button("Copy Context") {
                                copyProfileContext(profile)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var documentsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Indexed Documents")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let root = rootURL {
                let documents = contextStore.getIndexedDocuments(for: root.path)
                
                if documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.6))
                        
                        Text("No documents indexed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Button("Reindex Repository") {
                            FilesystemContextService.shared.refreshIfNeeded()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(documents, id: \.id, selection: $selectedDocument) { document in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.relPath)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("\(document.byteSize) bytes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("Indexed: \(document.lastIndexedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            let segments = contextStore.getSegments(for: document.id, minScore: 1)
                            Text("\(segments.count) segments extracted")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if let document = selectedDocument {
                        Button("Copy Document Context") {
                            copyDocumentContext(document)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var quickActionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context Actions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Copy relevant project information to your clipboard for use with AI coding assistants like Cursor, GitHub Copilot, or Claude.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Button(action: { copyProjectOverview() }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy Project Overview")
                                .fontWeight(.medium)
                            Text("High-level project structure and key files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(rootURL == nil)
                
                Button(action: { copyFileStructure() }) {
                    HStack {
                        Image(systemName: "folder.badge.tree")
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy File Structure")
                                .fontWeight(.medium)
                            Text("Directory tree with file listings and tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(rootURL == nil)
                
                Button(action: { copyFileStructureWithTags() }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy File Structure (with tags)")
                                .fontWeight(.medium)
                            Text("relPath — small purpose tag per file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(rootURL == nil)
                
                Button(action: { copyDocumentationContext() }) {
                    HStack {
                        Image(systemName: "book.pages")
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy Documentation")
                                .fontWeight(.medium)
                            Text("README and markdown documentation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(rootURL == nil)
                
                if let profile = selectedProfile {
                    Button(action: { copyProfileContext(profile) }) {
                        HStack {
                            Image(systemName: "person.badge.key")
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy Profile Context (\(profile.name))")
                                    .fontWeight(.medium)
                                Text("Focused context from selected profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // GitIngest Repository Sync Actions
            if UserDefaults.standard.useGitIngest {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repository Sync (GitIngest)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: { performFullRepoSync() }) {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Full Repository Sync")
                                    .fontWeight(.medium)
                                Text("Analyze entire repository with GitIngest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if contextStore.isGitIngestSyncing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .padding()
                        .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(rootURL == nil || contextStore.isGitIngestSyncing)
                    
                    Button(action: { copyEnhancedRepositoryContext() }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard.fill")
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy Enhanced Repository Context")
                                    .fontWeight(.medium)
                                Text("Full repo analysis with GitIngest insights")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .padding()
                        .background(Color.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(rootURL == nil)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("GitIngest Context Generator (Beta)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Mode picker
                    HStack {
                        Text("Mode")
                        Spacer()
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(GitIngestService.ContextMode.allCases, id: \.self) { mode in
                                Text(String(describing: mode))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if selectedMode == .customFiltered {
                        // Include patterns
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Include Patterns (comma-separated)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g., *.swift, *.md", text: Binding(
                                get: { customPatterns.include.joined(separator: ", ") },
                                set: { customPatterns.include = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                            ))
                        }
                        
                        // Exclude patterns
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Exclude Patterns (comma-separated)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g., node_modules/*, .git/*", text: Binding(
                                get: { customPatterns.exclude.joined(separator: ", ") },
                                set: { customPatterns.exclude = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                            ))
                        }
                        
                        // Max file size slider
                        HStack {
                            Text("Max File Size")
                            Spacer()
                            Slider(value: Binding(get: { Double(customPatterns.maxFileSize) }, set: { customPatterns.maxFileSize = Int($0) }), in: 1024...204800, step: 1024)
                            Text("\(customPatterns.maxFileSize / 1024)KB")
                                .monospacedDigit()
                                .frame(width: 50)
                        }
                    }
                    
                    Button(action: { generateAndCopyGitIngestContext() }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate & Copy")
                                .fontWeight(.medium)
                            Spacer()
                            if gitIngestService.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(rootURL == nil)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var noProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.6))
            
            Text("No Project Detected")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("VoiceInk couldn't detect a project in the current directory. Make sure you're in a project folder with files like README.md, package.json, or other project files.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Set Custom Project Root") {
                setCustomProjectRoot()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Profile Creation Sheet
    
    private var profileCreationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Dictionary Profile")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.subheadline)
                TextField("e.g., Voice Transcription Features", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.subheadline)
                TextField("Brief description of this profile's focus", text: $newProfileDescription)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    showingProfileCreation = false
                    newProfileName = ""
                    newProfileDescription = ""
                }
                
                Spacer()
                
                Button("Create") {
                    createProfile()
                }
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    // MARK: - Repository Manager Sheet
    
    private var repositoryManagerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repository Management")
                .font(.headline)
            
            Text("Manage indexed repositories and their context data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let root = rootURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Repository")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(root.path)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    
                    HStack {
                        Button("Reindex Repository") { reindex() }
                            .disabled(contextStore.isIndexing)
                        
                        Spacer()
                        
                        Button("Clear Index") { clearIndex() }
                            .foregroundStyle(.red)
                    }
                }
            }
            
            HStack {
                Button("Close") {
                    showingRepositoryManager = false
                }
                
                Spacer()
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
    
    // MARK: - Helper Functions
    
    private func reload() {
        guard let root = FilesystemContextService.shared.detectActiveProjectRoot() else { 
            self.rootURL = nil
            return 
        }
        self.rootURL = root
        
        // Auto-create default profile if none exist, then select first
        let profiles = contextStore.getProfiles(for: root.path)
        if profiles.isEmpty {
            let defaultProfile = contextStore.createProfile(
                name: "Default Project Profile",
                projectRoot: root.path,
                profileDescription: "Automatically created default profile for managing project context and terminology"
            )
            selectedProfile = defaultProfile
        } else if selectedProfile == nil {
            selectedProfile = profiles.first
        }
    }
    
    private func reindex() {
        FilesystemContextService.shared.refreshIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { 
            reload() 
        }
    }
    
    private func clearIndex() {
        guard let root = rootURL else { return }
        contextStore.clearIndex(for: root.path)
        reload()
    }
    
    private func setCustomProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.manualProjectRootPath = url.path
            FilesystemContextService.shared.refreshIfNeeded()
            reload()
        }
    }
    
    // MARK: - Context Copy Functions
    
    private func copyProjectOverview() {
        guard let root = rootURL else { return }
        
        var overview = "# \(root.lastPathComponent) - Project Overview\n\n"
        overview += "**Project Path:** \(root.path)\n\n"
        
        let documents = contextStore.getIndexedDocuments(for: root.path)
        overview += "**Indexed Documents:** \(documents.count)\n"
        
        let segments = contextStore.getAllSegments(for: root.path, minScore: 3)
        overview += "**Key Segments:** \(segments.count)\n\n"
        
        overview += "## Key Documentation\n"
        for document in documents.prefix(10) {
            overview += "- \(document.relPath)\n"
        }
        
        overview += "\n## Important Code Segments\n"
        for segment in segments.prefix(15) {
            overview += "- \(segment.kind.displayName): \(segment.preview.prefix(80))...\n"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(overview, forType: .string)
        
        copyFeedbackMessage = "Project overview copied!"
        showCopyFeedback()
    }
    
    private func copyFileStructure() {
        guard let root = rootURL else { return }
        
        var structure = "# \(root.lastPathComponent) - File Structure\n\n"
        structure += "```\n"
        
        // Get basic file structure from indexed documents
        let documents = contextStore.getIndexedDocuments(for: root.path)
        let paths = documents.map { $0.relPath }.sorted()
        
        for path in paths {
            let depth = path.components(separatedBy: "/").count - 1
            let indent = String(repeating: "  ", count: depth)
            let filename = URL(fileURLWithPath: path).lastPathComponent
            structure += "\(indent)├── \(filename)\n"
        }
        
        structure += "```\n\n"
        structure += "**Total Files Indexed:** \(documents.count)\n"
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(structure, forType: .string)
        
        copyFeedbackMessage = "File structure copied!"
        showCopyFeedback()
    }
    
    private func copyFileStructureWithTags() {
        guard let root = rootURL else { return }
        let text = ProjectFileIndexStore.shared.exportFileStructure(rootPath: root.path)
        var structure = "# \(root.lastPathComponent) - File Structure (with tags)\n\n"
        structure += "````\n"
        structure += text
        structure += "````\n"
        structure += "\n**Total Files Indexed:** \(ProjectFileIndexStore.shared.files(for: root.path).count)\n"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(structure, forType: .string)
        copyFeedbackMessage = "File structure (with tags) copied!"
        showCopyFeedback()
    }
    
    private func copyDocumentationContext() {
        guard let root = rootURL else { return }
        
        var docs = "# \(root.lastPathComponent) - Documentation Context\n\n"
        
        let documents = contextStore.getIndexedDocuments(for: root.path)
        let markdownDocs = documents.filter { $0.relPath.lowercased().contains("readme") || $0.relPath.hasSuffix(".md") }
        
        for document in markdownDocs.prefix(5) {
            docs += "## \(document.relPath)\n"
            let segments = contextStore.getSegments(for: document.id, minScore: 2)
            for segment in segments.prefix(10) {
                if segment.kind == .heading || segment.kind == .emphasis {
                    docs += "\(segment.content)\n\n"
                }
            }
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(docs, forType: .string)
        
        copyFeedbackMessage = "Documentation copied!"
        showCopyFeedback()
    }
    
    private func copyDocumentContext(_ document: IndexedDocument) {
        var context = "# Document: \(document.relPath)\n\n"
        
        let segments = contextStore.getSegments(for: document.id, minScore: 1)
        for segment in segments {
            context += "## \(segment.kind.displayName) (Score: \(segment.score))\n"
            context += "\(segment.content)\n\n"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        
        copyFeedbackMessage = "Document context copied!"
        showCopyFeedback()
    }
    
    private func copyProfileContext(_ profile: DictionaryProfile) {
        let dictionary = contextStore.generateDictionary(for: profile)
        let context = formatDictionaryForContext(dictionary, profileName: profile.name)
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        
        copyFeedbackMessage = "Profile context copied!"
        showCopyFeedback()
    }
    
    private func generateAndCopyGitIngestContext() {
        guard let root = rootURL else { return }
        Task {
            do {
                let result = try await gitIngestService.generateContext(for: root, mode: selectedMode, customPatterns: customPatterns, token: UserDefaults.standard.gitIngestToken)
                var full = ""
                // Serialize summary as JSON for clarity
                if let data = try? JSONEncoder().encode(result.summary), let s = String(data: data, encoding: .utf8) {
                    full += "Repository Summary\n" + s + "\n\n"
                }
                full += result.tree + "\n\n" + result.content
                await MainActor.run {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(full, forType: .string)
                    copyFeedbackMessage = "GitIngest context copied!"
                    showCopyFeedback()
                }
            } catch {
                await MainActor.run {
                    copyFeedbackMessage = "Generation failed: \(error.localizedDescription)"
                    showCopyFeedback()
                }
                logger.error("GitIngest generation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportDictionary(for profile: DictionaryProfile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "dictionary-\(profile.name.replacingOccurrences(of: " ", with: "-")).md"
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let dest = panel.url {
            do {
                let dictionary = contextStore.generateDictionary(for: profile)
                let markdown = formatDictionaryAsMarkdown(dictionary, profileName: profile.name)
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                logger.info("Exported dictionary to: \(dest.path)")
                
                copyFeedbackMessage = "Dictionary exported!"
                showCopyFeedback()
            } catch {
                logger.error("Dictionary export failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func showCopyFeedback() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
        }
    }
    
    // MARK: - GitIngest Actions
    
    private func performFullRepoSync() {
        guard let root = rootURL else { return }
        
        Task {
            do {
                try await contextStore.performFullRepoSync(rootURL: root)
                await MainActor.run {
                    copyFeedbackMessage = "Repository sync completed!"
                    showCopyFeedback()
                }
            } catch {
                await MainActor.run {
                    copyFeedbackMessage = "Sync failed: \(error.localizedDescription)"
                    showCopyFeedback()
                }
                logger.error("Full repo sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func copyEnhancedRepositoryContext() {
        guard let root = rootURL else { return }
        
        Task {
            do {
                let enhancedContext = try await contextStore.createEnhancedDictionary(for: root.path)
                
                await MainActor.run {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(enhancedContext, forType: .string)
                    
                    copyFeedbackMessage = "Enhanced repository context copied!"
                    showCopyFeedback()
                }
            } catch {
                await MainActor.run {
                    copyFeedbackMessage = "Failed to copy enhanced context"
                    showCopyFeedback()
                }
                logger.error("Enhanced context copy failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func createProfile() {
        guard let root = rootURL else { return }
        
        let profile = contextStore.createProfile(
            name: newProfileName.trimmingCharacters(in: .whitespacesAndNewlines),
            projectRoot: root.path,
            profileDescription: newProfileDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        selectedProfile = profile
        showingProfileCreation = false
        newProfileName = ""
        newProfileDescription = ""
    }
    
    private func exportDictionary() {
        guard let profile = selectedProfile else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "dictionary-\(profile.name.replacingOccurrences(of: " ", with: "-")).md"
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let dest = panel.url {
            do {
                let dictionary = contextStore.generateDictionary(for: profile)
                let markdown = formatDictionaryAsMarkdown(dictionary, profileName: profile.name)
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                logger.info("Exported dictionary to: \(dest.path)")
            } catch {
                logger.error("Dictionary export failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDictionaryAsMarkdown(_ entries: [DictionaryEntry], profileName: String) -> String {
        var markdown = """
        # Dictionary Profile: \(profileName)
        
        Generated: \(Date().formatted())
        
        ## High-Quality Terms (\(entries.count))
        
        """
        
        for entry in entries {
            let tags = entry.tags.map { "[\($0)]" }.joined(separator: " ")
            let refs = entry.refs.prefix(3).joined(separator: ", ")
            markdown += "- **\(entry.label)** \(tags) — refs: \(refs)\n"
            if !entry.examples.isEmpty {
                markdown += "  - _\(entry.examples[0])_\n"
            }
            markdown += "\n"
        }
        
        return markdown
    }
    
    private func pushToCursor() {
        guard let profile = selectedProfile else { return }
        
        let dictionary = contextStore.generateDictionary(for: profile)
        let context = formatDictionaryForContext(dictionary, profileName: profile.name)
        
        // Copy to clipboard for now - could be enhanced to integrate with Cursor directly
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
        }
        
        logger.info("Pushed \(dictionary.count) dictionary entries to clipboard for Cursor")
    }
    
    private func formatDictionaryForContext(_ entries: [DictionaryEntry], profileName: String) -> String {
        var context = "# \(profileName) - Project Context\n\n"
        context += "**Generated:** \(Date().formatted())\n"
        context += "**Total Terms:** \(entries.count)\n\n"
        
        context += "## Key Terms and Concepts\n\n"
        for entry in entries.prefix(50) { // Limit for context window
            let tags = entry.tags.isEmpty ? "" : " [\(entry.tags.joined(separator: ", "))]"
            context += "- **\(entry.label)**\(tags): \(entry.examples.first ?? "")\n"
        }
        
        return context
    }
}

// MARK: - Supporting Views

struct ProfileCard: View {
    let profile: DictionaryProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profile.name)
                .font(.system(.caption, weight: .medium))
                .lineLimit(1)
            
            if !profile.profileDescription.isEmpty {
                Text(profile.profileDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text("\(profile.pinnedSegmentIDs.count) pinned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 140, height: 70)
        .background(
            isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? .blue : .clear, lineWidth: 1)
        )
        .onTapGesture { onTap() }
    }
}
