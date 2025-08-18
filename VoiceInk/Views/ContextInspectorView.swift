import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

struct ContextInspectorView: View {
    @State private var rootURL: URL?
    @State private var selectedTab = 0
    @State private var selectedDocument: IndexedDocument?
    @State private var selectedSegment: MarkdownSegment?
    @State private var showingProfileCreation = false
    @State private var newProfileName = ""
    @State private var newProfileDescription = ""
    @State private var searchQuery = ""
    @State private var selectedProfile: DictionaryProfile?
    @State private var selectedSegmentKind: SegmentKind?
    @State private var minScore = 3
    @State private var copiedAnchor = ""
    @State private var showingCopyFeedback = false
    
    @StateObject private var contextStore = ContextIndexStore.shared
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContextInspectorView")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            TabView(selection: $selectedTab) {
                documentsTab
                    .tabItem { Label("Documents", systemImage: "doc.text") }
                    .tag(0)
                
                segmentsTab
                    .tabItem { Label("Segments", systemImage: "text.quote") }
                    .tag(1)
                
                profilesTab
                    .tabItem { Label("Profiles", systemImage: "person.2") }
                    .tag(2)
            }
            .frame(minWidth: 720, minHeight: 500)
        }
        .padding()
        .onAppear { reload() }
        .sheet(isPresented: $showingProfileCreation) {
            profileCreationSheet
        }
        .overlay(alignment: .topTrailing) {
            if showingCopyFeedback {
                Text("Copied!")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showingCopyFeedback = false
                        }
                    }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Context Window Manager").font(.headline)
                Text(rootURL?.path ?? "No project detected").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    if let root = rootURL {
                        let documents = contextStore.getIndexedDocuments(for: root.path)
                        let segments = contextStore.getAllSegments(for: root.path, minScore: 1)
                        Text("Indexed: \(documents.count) docs, \(segments.count) segments").font(.caption2)
                    }
                    if contextStore.isIndexing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Indexing...")
                        }
                        .font(.caption2)
                    }
                }
            }
            Spacer()
            
            HStack(spacing: 8) {
                Button("Reindex") { reindex() }
                    .disabled(contextStore.isIndexing)
                
                Button("Export Dictionary") { exportDictionary() }
                    .disabled(selectedProfile == nil)
                
                if let profile = selectedProfile {
                    Button("Push to Cursor") { pushToCursor(profile: profile) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Documents Tab
    
    private var documentsTab: some View {
        HSplitView {
            // Documents list
            VStack(alignment: .leading, spacing: 8) {
                Text("Markdown Documents").font(.subheadline).fontWeight(.medium)
                
                if let root = rootURL {
                    let documents = contextStore.getIndexedDocuments(for: root.path)
                    
                    if documents.isEmpty {
                        Text("No documents indexed yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(documents, id: \.id) { document in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.relPath)
                                    .font(.system(.body, design: .monospaced))
                                HStack {
                                    Text("\(document.byteSize) bytes")
                                    Spacer()
                                    Text(document.lastIndexedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .background(
                                selectedDocument?.id == document.id ? 
                                Color.blue.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDocument = document
                            }
                        }
                        .listStyle(.sidebar)
                    }
                } else {
                    Text("No project root detected")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 250)
            
            // Document details
            VStack(alignment: .leading, spacing: 8) {
                if let document = selectedDocument {
                    Text("Document: \(document.relPath)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    let segments = contextStore.getSegments(for: document.id, minScore: 1)
                    
                    if segments.isEmpty {
                        Text("No segments found")
                            .foregroundStyle(.secondary)
                    } else {
                        List(segments, id: \.id) { segment in
                            SegmentRowView(segment: segment) {
                                copyAnchor(segment.anchor)
                            }
                        }
                    }
                } else {
                    Text("Select a document to view its segments")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
    }
    
    // MARK: - Segments Tab
    
    private var segmentsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filters
            HStack {
                TextField("Search segments...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Kind", selection: $selectedSegmentKind) {
                    Text("All").tag(nil as SegmentKind?)
                    ForEach(SegmentKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind as SegmentKind?)
                    }
                }
                .frame(width: 120)
                
                HStack {
                    Text("Min Score:")
                    Stepper(value: $minScore, in: 1...10) {
                        Text("\(minScore)")
                    }
                }
            }
            
            // Segments list
            if let root = rootURL {
                let allSegments = contextStore.getAllSegments(for: root.path, minScore: minScore)
                let filteredSegments = filterSegments(allSegments)
                
                if filteredSegments.isEmpty {
                    Text("No segments match the current filters")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredSegments, id: \.id, selection: $selectedSegment) { segment in
                        SegmentRowView(segment: segment, showDocument: true) {
                            copyAnchor(segment.anchor)
                        }
                    }
                }
            } else {
                Text("No project root detected")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Profiles Tab
    
    private var profilesTab: some View {
        HSplitView {
            // Profiles list
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dictionary Profiles").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Button(action: { showingProfileCreation = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                Text("Profiles organize and filter project context for specific coding tasks. Pin relevant segments to create focused dictionaries for AI assistance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                if let root = rootURL {
                    let profiles = contextStore.getProfiles(for: root.path)
                    
                    if profiles.isEmpty {
                        Text("No profiles created yet")
                            .foregroundStyle(.secondary)
                    } else {
                        List(profiles, id: \.id, selection: $selectedProfile) { profile in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).fontWeight(.medium)
                                if !profile.profileDescription.isEmpty {
                                    Text(profile.profileDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("\(profile.pinnedSegmentIDs.count) pinned")
                                    Spacer()
                                    Text(profile.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(minWidth: 200)
            
            // Profile details
            VStack(alignment: .leading, spacing: 8) {
                if let profile = selectedProfile {
                    Text("Profile: \(profile.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !profile.profileDescription.isEmpty {
                        Text(profile.profileDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    let pinnedSegments = contextStore.getAllSegments(for: profile.projectRoot, minScore: 1)
                        .filter { profile.pinnedSegmentIDs.contains($0.id) }
                    
                    if pinnedSegments.isEmpty {
                        Text("No segments pinned to this profile")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Pinned Segments (\(pinnedSegments.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        List(pinnedSegments, id: \.id) { segment in
                            SegmentRowView(segment: segment, showDocument: true) {
                                copyAnchor(segment.anchor)
                            }
                        }
                    }
                } else {
                    Text("Select a profile to view details")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
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
    
    // MARK: - Helper Functions
    
    private func reload() {
        guard let root = FilesystemContextService.shared.detectActiveProjectRoot() else { return }
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
        
        // Select first document if none selected (deterministic selection)
        if selectedDocument == nil {
            let documents = contextStore.getIndexedDocuments(for: root.path)
            selectedDocument = documents.first
        }
    }
    
    private func reindex() {
        FilesystemContextService.shared.refreshIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { reload() }
    }
    
    private func filterSegments(_ segments: [MarkdownSegment]) -> [MarkdownSegment] {
        var filtered = segments
        
        // Filter by kind
        if let kind = selectedSegmentKind {
            filtered = filtered.filter { $0.kind == kind }
        }
        
        // Filter by search query
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { segment in
                segment.content.lowercased().contains(query) ||
                segment.preview.lowercased().contains(query) ||
                segment.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        return filtered
    }
    
    private func copyAnchor(_ anchor: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(anchor, forType: .string)
        copiedAnchor = anchor
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
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
    
    private func pushToCursor(profile: DictionaryProfile) {
        let dictionary = contextStore.generateDictionary(for: profile)
        let context = formatDictionaryForContext(dictionary)
        
        // Copy to clipboard for now - could be enhanced to integrate with Cursor directly
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopyFeedback = true
        }
        
        logger.info("Pushed \(dictionary.count) dictionary entries to clipboard for Cursor")
    }
    
    private func formatDictionaryForContext(_ entries: [DictionaryEntry]) -> String {
        var context = "# Project Context Dictionary\n\n"
        
        for entry in entries.prefix(50) { // Limit for context window
            context += "- \(entry.label): \(entry.examples.first ?? "")\n"
        }
        
        return context
    }
    
    private func syncClaude() {
        guard let root = rootURL else { return }
        do {
            // Implementation for syncing CLAUDE.md will be added here
            logger.info("CLAUDE.md sync functionality to be implemented")
        } catch {
            logger.error("CLAUDE sync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct SegmentRowView: View {
    let segment: MarkdownSegment
    var showDocument = false
    let onCopyAnchor: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(segment.kind.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(kindColor, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(.white)
                
                if showDocument {
                    Text(documentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Score: \(segment.score)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(action: onCopyAnchor) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy anchor reference")
            }
            
            Text(segment.preview)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Text("L\(segment.lineStart)")
                if segment.lineEnd != segment.lineStart {
                    Text("– L\(segment.lineEnd)")
                }
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(segment.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var kindColor: Color {
        switch segment.kind {
        case .heading: return .blue
        case .code: return .green
        case .emphasis: return .orange
        case .list: return .purple
        case .quote: return .brown
        case .table: return .red
        case .paragraph: return .gray
        }
    }
    
    private var documentName: String {
        // Extract just the filename from the anchor
        if let range = segment.anchor.range(of: "md:([^#]+)", options: .regularExpression) {
            let fullPath = String(segment.anchor[range]).dropFirst(3) // Remove "md:"
            return URL(fileURLWithPath: String(fullPath)).lastPathComponent
        }
        return "Unknown"
    }
}
