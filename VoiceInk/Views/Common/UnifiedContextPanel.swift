import SwiftUI

struct UnifiedContextPanel: View {
    @StateObject private var backendRegistry = VoiceInkBackendRegistry.shared
    @StateObject private var smartDefaults = SmartDefaultsService.shared
    
    @State private var selectedProject: Project?
    @State private var searchText = ""
    @State private var selectedFilter: ContextFilter = .all
    @State private var showingProjectSetup = false
    @State private var showingSourceSetup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("Project Context")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("New Project") {
                        showingProjectSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Search and Filters
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search context...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                    )
                    
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ContextFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(20)
            
            // Content
            if let selectedProject = selectedProject {
                projectContextView(for: selectedProject)
            } else {
                projectSelectionView
            }
        }
        .sheet(isPresented: $showingProjectSetup) {
            ProjectSetupWorkflow()
        }
        .sheet(isPresented: $showingSourceSetup) {
            SourceSetupWorkflow(project: selectedProject!)
        }
    }
    
    // MARK: - Project Selection View
    
    private var projectSelectionView: some View {
        VStack(spacing: 20) {
            if let projects = backendRegistry.projectRegistry?.projects, !projects.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(projects) { project in
                        ProjectCard(
                            project: project,
                            isSelected: selectedProject?.id == project.id,
                            onSelect: { selectedProject = project }
                        )
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Projects Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create your first project to start building context-aware transcriptions")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Project") {
                        showingProjectSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
            }
        }
        .padding(20)
    }
    
    // MARK: - Project Context View
    
    @ViewBuilder
    private func projectContextView(for project: Project) -> some View {
        VStack(spacing: 0) {
            // Project Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(project.projectDescription.isEmpty ? "No description" : project.projectDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Back") {
                    selectedProject = nil
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            
            // Project Tabs
            TabView {
                // Sources Tab
                SourcesTab(project: project, onAddSource: {
                    showingSourceSetup = true
                })
                .tabItem {
                    Label("Sources", systemImage: "folder.badge.gearshape")
                }
                
                // Context Tab
                ContextTab(project: project)
                    .tabItem {
                        Label("Context", systemImage: "doc.text.magnifyingglass")
                    }
                
                // Settings Tab
                ProjectSettingsTab(project: project)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Supporting Views

struct ProjectCard: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(project.projectDescription.isEmpty ? "No description" : project.projectDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(project.sources.count) sources")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(16)
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
}

struct SourcesTab: View {
    let project: Project
    let onAddSource: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Context Sources")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Source") {
                    onAddSource()
                }
                .buttonStyle(.bordered)
            }
            
            if !project.sources.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(project.sources) { source in
                        SourceRow(source: source)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No Sources Yet")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Add Git repositories, documentation files, or web sources to build context")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        }
    }
}

struct SourceRow: View {
    let source: ContextSource
    
    var body: some View {
        HStack {
            Image(systemName: getSourceIcon(for: source.sourceType.rawValue))
                .font(.title3)
                .foregroundColor(getSourceColor(for: source.sourceType.rawValue))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(getSourceTitle(for: source.sourceType.rawValue))
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(getSourceDescription(for: source.sourceType.rawValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(source.syncStatus)
                    .font(.caption)
                    .foregroundColor(getStatusColor(for: source.syncStatus))
                
                if let lastSyncAt = source.lastSyncAt {
                    Text(lastSyncAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private func getSourceIcon(for type: String) -> String {
        switch type {
        case "git_ingest":
            return "git.branch"
        case "manual_notes":
            return "note.text"
        case "markdown":
            return "doc.text"
        case "documentation":
            return "book"
        default:
            return "questionmark.circle"
        }
    }
    
    private func getSourceColor(for type: String) -> Color {
        switch type {
        case "git_ingest":
            return .orange
        case "manual_notes":
            return .green
        case "markdown":
            return .blue
        case "documentation":
            return .purple
        default:
            return .gray
        }
    }
    
    private func getSourceTitle(for type: String) -> String {
        switch type {
        case "git_ingest":
            return "Git Repository"
        case "manual_notes":
            return "Manual Notes"
        case "markdown":
            return "Markdown Files"
        case "documentation":
            return "Documentation"
        default:
            return "Unknown Source"
        }
    }
    
    private func getSourceDescription(for type: String) -> String {
        switch type {
        case "git_ingest":
            return "Git repository source for code context"
        case "manual_notes":
            return "Manual notes and documentation"
        case "markdown":
            return "Markdown file source"
        case "documentation":
            return "Documentation source"
        default:
            return "Source configuration details"
        }
    }
    
    private func getStatusColor(for status: String?) -> Color {
        guard let status = status else { return .gray }
        
        switch status {
        case "active":
            return .green
        case "inactive":
            return .orange
        case "error":
            return .red
        default:
            return .gray
        }
    }
}

struct ContextTab: View {
    let project: Project
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Assembled Context")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    // Refresh context assembly
                }
                .buttonStyle(.bordered)
            }
            
            // Context preview would go here
            Text("Context assembly preview will be displayed here")
                .foregroundColor(.secondary)
                .padding(40)
        }
    }
}

struct ProjectSettingsTab: View {
    let project: Project
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Project Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Project settings would go here
            Text("Project configuration options will be displayed here")
                .foregroundColor(.secondary)
                .padding(40)
        }
    }
}

// MARK: - Supporting Types

enum ContextFilter: String, CaseIterable {
    case all = "All"
    case git = "Git"
    case web = "Web"
    case files = "Files"
    case chat = "Chat"
    
    var displayName: String {
        return rawValue
    }
}

#Preview {
    UnifiedContextPanel()
}
