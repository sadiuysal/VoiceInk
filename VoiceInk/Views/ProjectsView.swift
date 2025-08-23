import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedTab: ProjectTab = .overview
    @State private var showingCreateProject = false
    @State private var showingContextManagement = false
    
    enum ProjectTab: String, CaseIterable {
        case overview = "Overview"
        case sources = "Sources"
        case dictionary = "Dictionary"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .sources: return "folder.badge.gearshape"
            case .dictionary: return "character.book.closed"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Projects List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Projects")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Context Management") {
                            showingContextManagement = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button(action: { showingCreateProject = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                if projects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Projects")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Create your first project to organize context sources and manage AI dictionaries.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Create Project") {
                            showingCreateProject = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    List(projects, selection: $selectedProject) { project in
                        ProjectRowView(project: project)
                            .tag(project)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 280)
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            // Project Detail View
            if let project = selectedProject {
                ProjectDetailView(project: project, selectedTab: $selectedTab)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Select a Project")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Choose a project from the sidebar to manage its sources, packs, and dictionary.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedProject == nil && !projects.isEmpty {
                selectedProject = projects.first
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView()
        }
        .onChange(of: showingContextManagement) { _, newValue in
            if newValue {
                ContextManagementWindowManager.shared.openContextManagementWindow()
                showingContextManagement = false
            }
        }
    }
}

// MARK: - Project Row View
struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !project.projectDescription.isEmpty {
                        Text(htmlString: project.projectDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let branch = project.currentBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "git.branch")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(branch)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let lastCommit = project.lastCommitHash {
                        HStack(spacing: 4) {
                            Image(systemName: "commit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(lastCommit.prefix(8))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                Label("\(project.sourceCount) sources", systemImage: "folder.badge.gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(project.packCount) packs", systemImage: "archivebox")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastSync = project.lastSyncDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    let project: Project
    @Binding var selectedTab: ProjectsView.ProjectTab
    
    var body: some View {
        VStack(spacing: 0) {
            // Project Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !project.projectDescription.isEmpty {
                            Text(htmlString: project.projectDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Git information
                if project.currentBranch != nil || project.remoteOrigin != nil {
                    HStack(spacing: 16) {
                        if let branch = project.currentBranch {
                            HStack(spacing: 4) {
                                Image(systemName: "git.branch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(branch)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let remote = project.remoteOrigin {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(remote)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if let lastCommit = project.lastCommitHash, let author = project.lastCommitAuthor {
                            HStack(spacing: 4) {
                                Image(systemName: "commit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(lastCommit.prefix(8)) by \(author)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                if let rootPath = project.rootPath {
                    HStack {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(rootPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(ProjectsView.ProjectTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab ?
                            Color.accentColor.opacity(0.1) :
                            Color.clear
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tab Content
            Group {
                switch selectedTab {
                case .overview:
                    ProjectOverviewView(project: project)
                case .sources:
                    ProjectSourcesView(project: project)
                case .dictionary:
                    ProjectDictionaryView(project: project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Project Tab Views
struct ProjectSourcesView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSource = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sources")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Source") {
                    showingAddSource = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Content
            if project.sources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Sources")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Add context sources like markdown files, documentation, or other reference materials.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Add First Source") {
                        showingAddSource = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(project.sources) { source in
                    SourceRowView(source: source)
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddSource) {
            AddSourceView(project: project)
        }
    }
}

struct SourceRowView: View {
    let source: ContextSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(source.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                Text(source.sourceType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if !source.sourceDescription.isEmpty {
                Text(source.sourceDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let path = source.sourcePath {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddSourceView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var description = ""
    @State private var sourcePath = ""
    @State private var sourceType: ContextSourceType = .markdown
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Source Details") {
                    TextField("Source Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $sourceType) {
                        ForEach(ContextSourceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Location") {
                    HStack {
                        TextField("Source Path (optional)", text: $sourcePath)
                        
                        Button("Browse") {
                            showingFileImporter = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Source")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    sourcePath = url.path
                }
            case .failure:
                break
            }
        }
    }
    
    private func addSource() {
        let source = ContextSource(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceType: sourceType,
            sourcePath: sourcePath.isEmpty ? nil : sourcePath,
            project: project
        )
        
        modelContext.insert(source)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to add source: \(error)")
        }
    }
}

struct ProjectPacksView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreatePack = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Context Packs")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create Pack") {
                    showingCreatePack = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Content
            if project.packs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Context Packs")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Create context packs to organize and filter dictionary terms for AI enhancement.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Create First Pack") {
                        showingCreatePack = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)], spacing: 20) {
                        ForEach(project.packs) { pack in
                            ContextPackRowView(pack: pack)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCreatePack) {
            CreatePackView(project: project)
        }
    }
}

struct ContextPackRowView: View {
    let pack: ContextPack
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    
                    if !pack.packDescription.isEmpty {
                        Text(pack.packDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(pack.isActive ? .green : .orange)
                }
            }
            
            Divider()
            
            HStack {
                Label("\(pack.termCount) terms", systemImage: "character.book.closed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(pack.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct CreatePackView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Pack Details") {
                    TextField("Pack Name", text: $name)
                }
            }
            .formStyle(.grouped)
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 400, height: 200)
    }
    
    private func createPack() {
        let pack = ContextPack(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            packDescription: "",
            project: project
        )
        
        modelContext.insert(pack)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to create pack: \(error)")
        }
    }
}

struct ProjectDictionaryView: View {
    let project: Project
    
    private var totalTerms: Int {
        project.packs.reduce(0) { $0 + $1.termCount }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Dictionary")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(totalTerms) total terms")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Content
            if project.packs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Dictionary Terms")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Create context packs with sources to generate dictionary terms for AI enhancement.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(project.packs) { pack in
                    Section(pack.name) {
                        HStack {
                            Text("\(pack.termCount) terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if pack.isActive {
                                Text("Active")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            } else {
                                Text("Inactive")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ProjectSyncView: View {
    let project: Project
    @StateObject private var contextStore = ContextIndexStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sync & Analysis")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if contextStore.isIndexing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Content
            VStack(spacing: 20) {
                if let lastSync = contextStore.lastIndexedAt {
                    VStack(spacing: 8) {
                        Text("Last Sync")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(lastSync, style: .relative)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Not Synced")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                
                VStack(spacing: 12) {
                    if let rootPath = project.rootPath {
                        Button("Sync Project Files") {
                            Task {
                                let url = URL(fileURLWithPath: rootPath)
                                await contextStore.indexProject(at: url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(contextStore.isIndexing)
                    } else {
                        Text("Set a root path in project settings to enable file synchronization.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    if contextStore.isIndexing {
                        VStack(spacing: 8) {
                            ProgressView(value: contextStore.indexProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(maxWidth: 200)
                            
                            Text("Indexing files...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
    }
}

// MARK: - Create Project View
struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var rootPath = ""
    @State private var showingFileImporter = false
    @State private var isDetecting = false
    @State private var detectedInfo: RepositoryInfo?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isDetecting {
                    // Detection in progress
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Detecting repository...")
                            .font(.headline)
                        
                        Text("Analyzing Git repository and extracting project information")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let info = detectedInfo {
                    // Repository detected - show summary
                    VStack(spacing: 20) {
                        // Success indicator
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            Text("Repository Detected!")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Repository info
                        VStack(alignment: .leading, spacing: 12) {
                            ProjectInfoRow(label: "Project Name", value: info.displayName)
                            ProjectInfoRow(label: "Current Branch", value: info.currentBranch)
                            if let remote = info.remoteOrigin {
                                ProjectInfoRow(label: "Remote Origin", value: remote)
                            }
                            ProjectInfoRow(label: "Last Commit", value: "\(info.lastCommit.shortHash) by \(info.lastCommit.author)")
                            if !info.projectDescription.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Description")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    HTMLTextView(info.projectDescription, maxHeight: 60)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.controlBackgroundColor))
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                        
                        // Path info
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            
                            Text(info.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button("Choose Different Folder") {
                                showingFileImporter = true
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Create Project") {
                                createProject()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                } else {
                    // Initial state - choose folder
                    VStack(spacing: 24) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                        
                        Text("Create Project from Repository")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Choose a Git repository folder to automatically detect project information and create a new project.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Choose Repository Folder") {
                            showingFileImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    rootPath = url.path
                    detectRepository()
                }
            case .failure:
                errorMessage = "Failed to select folder"
            }
        }
    }
    
    private func detectRepository() {
        guard !rootPath.isEmpty else { return }
        
        isDetecting = true
        errorMessage = nil
        detectedInfo = nil
        
        Task {
            do {
                let info = try await GitService.shared.detectRepository(at: rootPath)
                await MainActor.run {
                    isDetecting = false
                    detectedInfo = info
                }
            } catch {
                await MainActor.run {
                    isDetecting = false
                    errorMessage = "Failed to detect repository: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createProject() {
        guard let info = detectedInfo else { return }
        
        let project = Project(
            name: info.displayName,
            projectDescription: info.projectDescription,
            rootPath: info.path,
            currentBranch: info.currentBranch,
            remoteOrigin: info.remoteOrigin,
            lastCommitHash: info.lastCommit.hash,
            lastCommitAuthor: info.lastCommit.author,
            lastCommitMessage: info.lastCommit.message,
            lastCommitDate: info.lastCommit.formattedDate
        )
        
        modelContext.insert(project)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create project: \(error.localizedDescription)"
        }
    }
}

// MARK: - Project Info Row Component
struct ProjectInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Spacer()
        }
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}