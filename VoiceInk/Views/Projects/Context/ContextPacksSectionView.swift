import SwiftUI
import SwiftData
import os

struct ContextPacksSectionView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @StateObject private var contextStore = ContextIndexStore.shared
    
    @State private var selectedPack: ContextPack?
    @State private var showingCreatePack = false
    @State private var showingPackEditor = false
    @State private var showingCopyFeedback = false
    @State private var copyFeedbackMessage = ""
    @State private var showingExportDialog = false
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContextPacksSection")
    
    var activePacks: [ContextPack] {
        project.packs.filter { $0.isActive }
    }
    
    var inactivePacks: [ContextPack] {
        project.packs.filter { !$0.isActive }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Context Packs")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Create and manage curated collections of project context for AI assistance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Create Pack") {
                        showingCreatePack = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Pack Statistics
                HStack(spacing: 24) {
                    StatLabel(
                        icon: "brain.head.profile",
                        title: "Total Packs",
                        value: "\(project.packs.count)",
                        color: .blue
                    )
                    
                    StatLabel(
                        icon: "checkmark.circle.fill",
                        title: "Active",
                        value: "\(activePacks.count)",
                        color: .green
                    )
                    
                    StatLabel(
                        icon: "pause.circle.fill",
                        title: "Inactive",
                        value: "\(inactivePacks.count)",
                        color: .orange
                    )
                    
                    let totalTerms = project.packs.reduce(0) { $0 + $1.termCount }
                    StatLabel(
                        icon: "character.book.closed",
                        title: "Total Terms",
                        value: "\(totalTerms)",
                        color: .purple
                    )
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Pack Management Content
            if project.packs.isEmpty {
                emptyStateView
            } else {
                packManagementView
            }
        }
        .sheet(isPresented: $showingCreatePack) {
            CreateContextPackView(project: project)
        }
        .sheet(isPresented: $showingPackEditor) {
            if let pack = selectedPack {
                EditContextPackView(pack: pack)
            }
        }
        .overlay(alignment: .topTrailing) {
            copyFeedbackOverlay
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Context Packs Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Context packs help organize project terminology and concepts for AI assistance. Create your first pack to get started.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            
            VStack(spacing: 12) {
                Button("Create First Context Pack") {
                    showingCreatePack = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Learn About Context Packs") {
                    // TODO: Show help or documentation
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Pack Management View
    
    private var packManagementView: some View {
        HStack(spacing: 0) {
            // Pack List
            VStack(spacing: 0) {
                if !activePacks.isEmpty {
                    packSection(title: "Active Packs", packs: activePacks, isActive: true)
                }
                
                if !inactivePacks.isEmpty {
                    if !activePacks.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    packSection(title: "Inactive Packs", packs: inactivePacks, isActive: false)
                }
                
                Spacer()
            }
            .frame(minWidth: 280, maxWidth: 320)
            
            Divider()
            
            // Pack Details
            if let pack = selectedPack {
                packDetailsView(pack: pack)
            } else {
                packSelectionPrompt
            }
        }
    }
    
    private func packSection(title: String, packs: [ContextPack], isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(packs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            LazyVStack(spacing: 1) {
                ForEach(packs) { pack in
                    ContextPackRow(
                        pack: pack,
                        isSelected: selectedPack?.id == pack.id,
                        onSelect: { selectedPack = pack }
                    )
                }
            }
        }
    }
    
    private var packSelectionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Select a Context Pack")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Choose a pack from the list to view its details, edit settings, or export context.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Pack Details View
    
    private func packDetailsView(pack: ContextPack) -> some View {
        VStack(spacing: 0) {
            // Pack Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !pack.packDescription.isEmpty {
                            Text(pack.packDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Menu("Actions") {
                        Button("Edit Pack") {
                            showingPackEditor = true
                        }
                        
                        Button("Duplicate Pack") {
                            duplicatePack(pack)
                        }
                        
                        Divider()
                        
                        Button("Export Context") {
                            exportPackContext(pack)
                        }
                        
                        Button("Copy to Clipboard") {
                            copyPackToClipboard(pack)
                        }
                        
                        Divider()
                        
                        if pack.isActive {
                            Button("Deactivate") {
                                togglePackActivation(pack)
                            }
                        } else {
                            Button("Activate") {
                                togglePackActivation(pack)
                            }
                        }
                        
                        Divider()
                        
                        Button("Delete Pack", role: .destructive) {
                            deletePack(pack)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Pack Metadata
                HStack(spacing: 20) {
                    MetadataItem(
                        icon: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill",
                        label: "Status",
                        value: pack.isActive ? "Active" : "Inactive",
                        color: pack.isActive ? .green : .orange
                    )
                    
                    MetadataItem(
                        icon: "character.book.closed",
                        label: "Terms",
                        value: "\(pack.termCount)",
                        color: .blue
                    )
                    
                    MetadataItem(
                        icon: "calendar",
                        label: "Updated",
                        value: pack.updatedAt.formatted(.relative(presentation: .named)),
                        color: .secondary
                    )
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Pack Content Management
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ActionCard(
                                title: "Copy Context",
                                subtitle: "Copy pack context to clipboard",
                                icon: "doc.on.clipboard",
                                iconColor: .blue,
                                action: { copyPackToClipboard(pack) }
                            )
                            
                            ActionCard(
                                title: "Export Pack",
                                subtitle: "Save as markdown file",
                                icon: "square.and.arrow.up",
                                iconColor: .green,
                                action: { exportPackContext(pack) }
                            )
                            
                            ActionCard(
                                title: "Enhance Pack",
                                subtitle: "AI-powered term suggestions",
                                icon: "wand.and.stars",
                                iconColor: .purple,
                                action: { enhancePack(pack) }
                            )
                            
                            ActionCard(
                                title: "Refresh",
                                subtitle: "Update pack content",
                                icon: "arrow.clockwise",
                                iconColor: .orange,
                                action: { refreshPack(pack) }
                            )
                        }
                    }
                    
                    // Pack Statistics and Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pack Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            DetailRow(label: "Created", value: pack.createdAt.formatted(date: .abbreviated, time: .shortened))
                            DetailRow(label: "Last Modified", value: pack.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            DetailRow(label: "Term Count", value: "\(pack.termCount)")
                            DetailRow(label: "Active Status", value: pack.isActive ? "Active" : "Inactive")
                            
                            if let lastSync = pack.lastSyncDate {
                                DetailRow(label: "Last Sync", value: lastSync.formatted(.relative(presentation: .named)))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.controlBackgroundColor))
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
    
    // MARK: - Pack Actions
    
    private func duplicatePack(_ pack: ContextPack) {
        let duplicatedPack = ContextPack(
            name: "\(pack.name) Copy",
            packDescription: pack.packDescription,
            project: project
        )
        
        // Copy additional properties
        duplicatedPack.isActive = false // Start as inactive
        duplicatedPack.termCount = pack.termCount
        
        modelContext.insert(duplicatedPack)
        
        do {
            try modelContext.save()
            selectedPack = duplicatedPack
            logger.info("Duplicated pack: \(pack.name)")
        } catch {
            logger.error("Failed to duplicate pack: \(error.localizedDescription)")
        }
    }
    
    private func togglePackActivation(_ pack: ContextPack) {
        pack.isActive.toggle()
        pack.updatedAt = Date()
        
        do {
            try modelContext.save()
            logger.info("Toggled pack activation: \(pack.name) -> \(pack.isActive)")
        } catch {
            logger.error("Failed to toggle pack activation: \(error.localizedDescription)")
        }
    }
    
    private func deletePack(_ pack: ContextPack) {
        modelContext.delete(pack)
        
        do {
            try modelContext.save()
            if selectedPack?.id == pack.id {
                selectedPack = nil
            }
            logger.info("Deleted pack: \(pack.name)")
        } catch {
            logger.error("Failed to delete pack: \(error.localizedDescription)")
        }
    }
    
    private func copyPackToClipboard(_ pack: ContextPack) {
        // TODO: Implement pack context copying using ContextIndexStore
        let context = "# \(pack.name) - Context Pack\n\n**Description:** \(pack.packDescription)\n\n**Terms:** \(pack.termCount)\n\n**Status:** \(pack.isActive ? "Active" : "Inactive")\n\n**Generated:** \(Date().formatted())"
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        
        copyFeedbackMessage = "Pack context copied!"
        showCopyFeedback()
    }
    
    private func exportPackContext(_ pack: ContextPack) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "context-pack-\(pack.name.replacingOccurrences(of: " ", with: "-")).md"
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let dest = panel.url {
            let context = "# \(pack.name) - Context Pack\n\n**Description:** \(pack.packDescription)\n\n**Terms:** \(pack.termCount)\n\n**Status:** \(pack.isActive ? "Active" : "Inactive")\n\n**Generated:** \(Date().formatted())\n\n## TODO: Implement full context export"
            
            do {
                try context.write(to: dest, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                
                copyFeedbackMessage = "Pack exported!"
                showCopyFeedback()
            } catch {
                logger.error("Pack export failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func enhancePack(_ pack: ContextPack) {
        // TODO: Implement AI-powered pack enhancement
        copyFeedbackMessage = "Enhancement feature coming soon!"
        showCopyFeedback()
    }
    
    private func refreshPack(_ pack: ContextPack) {
        // TODO: Implement pack content refresh
        pack.updatedAt = Date()
        
        do {
            try modelContext.save()
            copyFeedbackMessage = "Pack refreshed!"
            showCopyFeedback()
        } catch {
            logger.error("Failed to refresh pack: \(error.localizedDescription)")
        }
    }
    
    private func showCopyFeedback() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
        }
    }
}

// MARK: - Supporting Views

struct StatLabel: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ContextPackRow: View {
    let pack: ContextPack
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(pack.isActive ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !pack.packDescription.isEmpty {
                        Text(pack.packDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\(pack.termCount) terms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(pack.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}



struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Context Pack Creation and Editing

struct CreateContextPackView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var isActive = true
    @State private var errorMessage: String?
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Pack Details") {
                    TextField("Pack Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("Active by default", isOn: $isActive)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 300)
    }
    
    private func createPack() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicate names
        if project.packs.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A context pack with this name already exists"
            return
        }
        
        let pack = ContextPack(
            name: trimmedName,
            packDescription: "",
            project: project,
            isActive: isActive
        )
        
        modelContext.insert(pack)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create pack: \(error.localizedDescription)"
        }
    }
}

struct EditContextPackView: View {
    let pack: ContextPack
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var description: String
    @State private var isActive: Bool
    @State private var filterConfig: PackFilterConfiguration
    @State private var showingAdvancedSettings = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false
    
    init(pack: ContextPack) {
        self.pack = pack
        self._name = State(initialValue: pack.name)
        self._description = State(initialValue: pack.packDescription)
        self._isActive = State(initialValue: pack.isActive)
        self._filterConfig = State(initialValue: pack.getFilterConfiguration())
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasChanges: Bool {
        name != pack.name ||
        description != pack.packDescription ||
        isActive != pack.isActive ||
        !areFilterConfigsEqual(filterConfig, pack.getFilterConfiguration())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Pack Details") {
                    TextField("Pack Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Pack Statistics") {
                    HStack {
                        Text("Terms")
                        Spacer()
                        Text("\(pack.termCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(pack.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Modified")
                        Spacer()
                        Text(pack.updatedAt, style: .relative)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = pack.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Filter Configuration") {
                    HStack {
                        Text("Content Filtering")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button("Advanced Settings") {
                            showingAdvancedSettings.toggle()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if showingAdvancedSettings {
                        filterConfigurationView
                    }
                }
                
                Section("Actions") {
                    Button("Refresh Pack Content") {
                        refreshPackContent()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Delete Pack", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Context Pack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePack()
                    }
                    .disabled(!isValid || !hasChanges)
                }
            }
            .alert("Delete Context Pack", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deletePack()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(pack.name)'? This action cannot be undone.")
            }
        }
        .frame(width: 600, height: 600)
    }
    
    private var filterConfigurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Include File Types")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("e.g., swift,md,txt", text: Binding(
                    get: { filterConfig.includeFileTypes.joined(separator: ",") },
                    set: { filterConfig.includeFileTypes = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Exclude File Types")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("e.g., log,tmp,cache", text: Binding(
                    get: { filterConfig.excludeFileTypes.joined(separator: ",") },
                    set: { filterConfig.excludeFileTypes = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Min Term Length")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    TextField("Min", value: $filterConfig.minTermLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Max Term Length")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    TextField("Max", value: $filterConfig.maxTermLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Term Limit")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    TextField("Limit", value: Binding(
                        get: { filterConfig.termLimit ?? 1000 },
                        set: { filterConfig.termLimit = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                
                Spacer()
            }
            
            HStack {
                Toggle("Include Code Blocks", isOn: $filterConfig.includeCodeBlocks)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                Toggle("Include Comments", isOn: $filterConfig.includeComments)
                    .toggleStyle(.checkbox)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.quaternarySystemFill))
        )
    }
    
    private func areFilterConfigsEqual(_ config1: PackFilterConfiguration, _ config2: PackFilterConfiguration) -> Bool {
        config1.includeFileTypes == config2.includeFileTypes &&
        config1.excludeFileTypes == config2.excludeFileTypes &&
        config1.minTermLength == config2.minTermLength &&
        config1.maxTermLength == config2.maxTermLength &&
        config1.minFrequency == config2.minFrequency &&
        config1.includeCodeBlocks == config2.includeCodeBlocks &&
        config1.includeComments == config2.includeComments &&
        config1.termLimit == config2.termLimit
    }
    
    private func savePack() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicate names (excluding current pack)
        if let project = pack.project,
           project.packs.contains(where: { $0.id != pack.id && $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A context pack with this name already exists"
            return
        }
        
        pack.name = trimmedName
        pack.packDescription = trimmedDescription
        pack.isActive = isActive
        
        // Update filter configuration
        do {
            try pack.setFilterConfiguration(filterConfig)
        } catch {
            errorMessage = "Failed to update filter configuration: \(error.localizedDescription)"
            return
        }
        
        pack.updateTimestamp()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
    
    private func refreshPackContent() {
        pack.updateSyncDate()
        
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to refresh pack: \(error.localizedDescription)"
        }
    }
    
    private func resetToDefaults() {
        filterConfig = PackFilterConfiguration()
        errorMessage = nil
    }
    
    private func deletePack() {
        modelContext.delete(pack)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete pack: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContextPacksSectionView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}