import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedTab: ProjectTab = .sources
    @State private var showingCreateProject = false
    
    enum ProjectTab: String, CaseIterable {
        case sources = "Sources"
        case packs = "Packs"
        case dictionary = "Dictionary"
        case sync = "Sync"
        
        var icon: String {
            switch self {
            case .sources: return "folder.badge.gearshape"
            case .packs: return "archivebox"
            case .dictionary: return "character.book.closed"
            case .sync: return "arrow.clockwise"
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
                    
                    Button(action: { showingCreateProject = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentColor)
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
    }
}

// MARK: - Project Row View
struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(project.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                if !project.isActive {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
            
            if !project.projectDescription.isEmpty {
                Text(project.projectDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Label("\(project.sourceCount)", systemImage: "folder")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Label("\(project.packCount)", systemImage: "archivebox")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let lastSync = project.lastSyncDate {
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                            Text(project.projectDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Settings") {
                        // TODO: Project settings
                    }
                    .buttonStyle(.bordered)
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
                case .sources:
                    ProjectSourcesView(project: project)
                case .packs:
                    ProjectPacksView(project: project)
                case .dictionary:
                    ProjectDictionaryView(project: project)
                case .sync:
                    ProjectSyncView(project: project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Placeholder Tab Views
struct ProjectSourcesView: View {
    let project: Project
    
    var body: some View {
        VStack {
            Text("Sources")
                .font(.title3)
            Text("Context sources for \(project.name)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProjectPacksView: View {
    let project: Project
    
    var body: some View {
        VStack {
            Text("Packs")
                .font(.title3)
            Text("Context packs for \(project.name)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProjectDictionaryView: View {
    let project: Project
    
    var body: some View {
        VStack {
            Text("Dictionary")
                .font(.title3)
            Text("Generated dictionary for \(project.name)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProjectSyncView: View {
    let project: Project
    
    var body: some View {
        VStack {
            Text("Sync")
                .font(.title3)
            Text("Sync operations for \(project.name)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Project View
struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var description = ""
    @State private var rootPath = ""
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Location") {
                    HStack {
                        TextField("Root Path (optional)", text: $rootPath)
                        
                        Button("Browse") {
                            showingFileImporter = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    rootPath = url.path
                }
            case .failure:
                break
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            projectDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            rootPath: rootPath.isEmpty ? nil : rootPath
        )
        
        modelContext.insert(project)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // TODO: Show error alert
            print("Failed to create project: \(error)")
        }
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}