import SwiftUI
import SwiftData
import os

struct ContextManagementWindow: View {

    @StateObject private var contextStore = ContextIndexStore.shared

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var windowManager: ContextManagementWindowManager
    @Query private var allProjects: [Project]
    @Query private var allSources: [ContextSource]
    @Query private var allPacks: [ContextPack]
    
    @State private var selectedTab: ContextTab = .contextPacks
    @State private var selectedPack: ContextPack?
    @State private var showingCreatePack = false
    @State private var showingCreateSource = false
    @State private var showingPackEditor = false
    @State private var showingCopyFeedback = false
    @State private var copyFeedbackMessage = ""
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContextManagementWindow")
    
    enum ContextTab: String, CaseIterable {
        case contextPacks = "Context Packs"
        case sources = "Sources"
        case bindings = "Bindings"
        
        var icon: String {
            switch self {
            case .contextPacks: return "brain.head.profile"
            case .sources: return "folder.badge.gearshape"
            case .bindings: return "link"
            }
        }
        
        var description: String {
            switch self {
            case .contextPacks: return "Create and manage context packs"
            case .sources: return "Configure repositories and data sources"
            case .bindings: return "Connect packs to Power Mode profiles"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Context Management")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Manage context packs and sources across all projects")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button("New Source") {
                                showingCreateSource = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("New Pack") {
                                showingCreatePack = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Close") {
                                windowManager.closeWindow()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Tab Navigation
                    HStack(spacing: 0) {
                        ForEach(ContextTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                VStack(spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 14))
                                        Text(tab.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                                    
                                    if selectedTab == tab {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 2)
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 2)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Tab Content
                Group {
                    switch selectedTab {
                    case .contextPacks:
                        ContextPacksTabView(
                            allPacks: allPacks,
                            allProjects: allProjects,
                            allSources: allSources,
                            selectedPack: $selectedPack,
                            showingPackEditor: $showingPackEditor,
                            packDetailsView: AnyView(packDetailsView),
                            packSelectionPrompt: AnyView(packSelectionPrompt)
                        )
                    case .sources:
                        SourcesTabView(
                            allSources: allSources,
                            allProjects: allProjects,
                            showingCreateSource: $showingCreateSource
                        )
                    case .bindings:
                        BindingsTabView(
                            allPacks: allPacks,
                            allProjects: allProjects
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Context Management")

        .sheet(isPresented: $showingCreatePack) {
            CreateContextPackSheet(
                allProjects: allProjects,
                allSources: allSources,
                modelContext: modelContext
            )
        }
        .sheet(isPresented: $showingCreateSource) {
            CreateSourceSheet(
                allProjects: allProjects,
                modelContext: modelContext
            )
        }
        .sheet(isPresented: $showingPackEditor) {
            if let pack = selectedPack {
                EditContextPackSheet(
                    pack: pack,
                    allProjects: allProjects,
                    allSources: allSources,
                    modelContext: modelContext
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            copyFeedbackOverlay
        }
    }
    
    private var copyFeedbackOverlay: some View {
        Group {
            if showingCopyFeedback {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(copyFeedbackMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(radius: 4)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingCopyFeedback = false
                        }
                    }
                }
            }
        }
    }
    
    private var packDetailsView: some View {
        Group {
            if let pack = selectedPack {
                PackDetailsContentView(
                    pack: pack,
                    allSources: allSources,
                    allProjects: allProjects,
                    showingPackEditor: $showingPackEditor
                )
            } else {
                packSelectionPrompt
            }
        }
    }
    
    private var packSelectionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Select a Context Pack")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Choose a pack from the list to view and edit its details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Context Packs Tab

struct ContextPacksTabView: View {
    let allPacks: [ContextPack]
    let allProjects: [Project]
    let allSources: [ContextSource]
    @Binding var selectedPack: ContextPack?
    @Binding var showingPackEditor: Bool
    let packDetailsView: AnyView
    let packSelectionPrompt: AnyView
    
    var body: some View {
        HStack(spacing: 0) {
            // Packs List
            VStack(spacing: 0) {
                HStack {
                    Text("Context Packs")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(allPacks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.controlBackgroundColor))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                if allPacks.isEmpty {
                    emptyPacksView
                } else {
                    packsListView
                }
            }
            .frame(minWidth: 300, maxWidth: 350)
            
            Divider()
            
            // Pack Details
            if let pack = selectedPack {
                packDetailsView
            } else {
                packSelectionPrompt
            }
        }
    }
    
    private var emptyPacksView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Context Packs")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Create your first context pack to start organizing project knowledge")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var packsListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(allPacks) { pack in
                    ContextManagementPackRow(
                        pack: pack,
                        allProjects: allProjects,
                        isSelected: selectedPack?.id == pack.id,
                        onSelect: { selectedPack = pack },
                        onEdit: { showingPackEditor = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
}

// MARK: - Sources Tab

struct SourcesTabView: View {
    let allSources: [ContextSource]
    let allProjects: [Project]
    @Binding var showingCreateSource: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Sources")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Configure repositories, Git ingest, and manual notes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Add Source") {
                    showingCreateSource = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Sources List
            if allSources.isEmpty {
                emptySourcesView
            } else {
                sourcesListView
            }
        }
    }
    
    private var emptySourcesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Sources Configured")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Add your first source to start gathering project context")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var sourcesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(allSources) { source in
                    SourceCard(source: source, allProjects: allProjects)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Bindings Tab

struct BindingsTabView: View {
    let allPacks: [ContextPack]
    let allProjects: [Project]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Power Mode Bindings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Connect context packs to AI enhancement profiles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Bindings Overview
            ScrollView {
                VStack(spacing: 24) {
                    // Active Bindings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Active Bindings")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        let activePacks = allPacks.filter { $0.isActive }
                        if activePacks.isEmpty {
                            Text("No active context packs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(activePacks) { pack in
                                    BindingCard(pack: pack, allProjects: allProjects)
                                }
                            }
                        }
                    }
                    
                    // Binding Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Binding Statistics")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ContextManagementStatisticCard(
                                title: "Total Packs",
                                value: "\(allPacks.count)",
                                icon: "brain.head.profile",
                                color: .blue
                            )
                            
                            ContextManagementStatisticCard(
                                title: "Active Packs",
                                value: "\(allPacks.filter { $0.isActive }.count)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            ContextManagementStatisticCard(
                                title: "Total Sources",
                                value: "\(allPacks.reduce(0) { $0 + $1.sourceIds.count })",
                                icon: "folder.badge.gearshape",
                                color: .purple
                            )
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
}

// MARK: - Supporting Views

struct ContextManagementPackRow: View {
    let pack: ContextPack
    let allProjects: [Project]
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    if !pack.packDescription.isEmpty {
                        Text(pack.packDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(pack.isActive ? .green : .orange)
                        
                        Text("\(pack.termCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
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



struct SourceCard: View {
    let source: ContextSource
    let allProjects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: source.sourceType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let project = source.project {
                        Text("Project: \(project.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                StatusBadge(
                    icon: source.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                    text: source.isEnabled ? "Enabled" : "Disabled",
                    color: source.isEnabled ? .green : .orange
                )
            }
            
            if !source.sourceDescription.isEmpty {
                Text(source.sourceDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let path = source.sourcePath {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            HStack {
                Text(source.sourceType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
                
                Spacer()
                
                if let lastSync = source.lastSyncAt {
                    Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
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

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
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
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct BindingCard: View {
    let pack: ContextPack
    let allProjects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(pack.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                StatusBadge(
                    icon: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill",
                    text: pack.isActive ? "Active" : "Inactive",
                    color: pack.isActive ? .green : .orange
                )
            }
            
            if !pack.packDescription.isEmpty {
                Text(pack.packDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(pack.termCount) terms")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(pack.sourceIds.count) sources")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

struct ContextManagementStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Pack Details Content

struct PackDetailsContentView: View {
    let pack: ContextPack
    let allSources: [ContextSource]
    let allProjects: [Project]
    @Binding var showingPackEditor: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PackHeaderView(pack: pack, showingPackEditor: $showingPackEditor)
                
                Divider()
                
                PackSourcesView(pack: pack, allSources: allSources, allProjects: allProjects)
                
                Divider()
                
                PackProjectsView(pack: pack, allProjects: allProjects)
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct PackHeaderView: View {
    let pack: ContextPack
    @Binding var showingPackEditor: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !pack.packDescription.isEmpty {
                        Text(pack.packDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Edit") {
                    showingPackEditor = true
                }
                .buttonStyle(.bordered)
            }
            
            PackStatusView(pack: pack)
        }
    }
}

struct PackStatusView: View {
    let pack: ContextPack
    
    var body: some View {
        HStack(spacing: 16) {
            StatusBadge(
                icon: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill",
                text: pack.isActive ? "Active" : "Inactive",
                color: pack.isActive ? .green : .orange
            )
            
            StatusBadge(
                icon: "character.book.closed",
                text: "\(pack.termCount) terms",
                color: .blue
            )
            
            if let lastSync = pack.lastSyncDate {
                StatusBadge(
                    icon: "clock",
                    text: lastSync.formatted(.relative(presentation: .named)),
                    color: .secondary
                )
            }
        }
    }
}

struct PackSourcesView: View {
    let pack: ContextPack
    let allSources: [ContextSource]
    let allProjects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sources")
                .font(.headline)
                .fontWeight(.semibold)
            
            if pack.sourceIds.isEmpty {
                Text("No sources configured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(pack.sourceIds, id: \.self) { sourceId in
                        if let source = allSources.first(where: { $0.id == sourceId }) {
                            PackSourceRow(source: source, allProjects: allProjects)
                        }
                    }
                }
            }
        }
    }
}

struct PackProjectsView: View {
    let pack: ContextPack
    let allProjects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Associated Projects")
                .font(.headline)
                .fontWeight(.semibold)
            
            PackProjectsListView(pack: pack, allProjects: allProjects)
        }
    }
}

struct PackProjectsListView: View {
    let pack: ContextPack
    let allProjects: [Project]
    
    private var associatedProjects: [Project] {
        allProjects.filter { project in
            project.packs.contains { $0.id == pack.id }
        }
    }
    
    var body: some View {
        Group {
            if associatedProjects.isEmpty {
                Text("Not associated with any projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(associatedProjects) { project in
                        ProjectRow(project: project)
                    }
                }
            }
        }
    }
}

struct PackSourceRow: View {
    let source: ContextSource
    let allProjects: [Project]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.sourceType.icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let path = source.sourcePath {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            StatusBadge(
                icon: source.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                text: source.isEnabled ? "Enabled" : "Disabled",
                color: source.isEnabled ? .green : .orange
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

#Preview {
    ContextManagementWindow()
        .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}
