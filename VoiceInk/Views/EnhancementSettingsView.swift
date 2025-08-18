import SwiftUI
import SwiftData

struct EnhancementSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Query private var contextPacks: [ContextPack]
    @State private var isEditingPrompt = false
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var selectedPackIds: Set<UUID> = []
    
    // Get currently bound pack IDs from user defaults or global enhancement settings
    private var boundPackIds: [UUID] {
        get {
            // For now, store in UserDefaults. Later can be moved to a global enhancement profile
            if let data = UserDefaults.standard.data(forKey: "enhancementBoundPackIds"),
               let ids = try? JSONDecoder().decode([UUID].self, from: data) {
                return ids
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "enhancementBoundPackIds")
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Main Settings Sections
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Post-processing")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Text("Configure AI-powered enhancement and context integration")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("Enable Post-processing", isOn: $enhancementService.isEnhancementEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .scaleEffect(1.2)
                        }
                        
                        if enhancementService.isEnhancementEnabled {
                            Text("Post-processing transforms your transcribed voice input using AI prompts and contextual information from bound projects.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    
                    // AI Provider Integration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Provider Integration")
                            .font(.headline)
                        
                        APIKeyManagementView()
                            .background(CardBackground(isSelected: false))
                    }
                    .padding()
                    .background(Color(.windowBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .disabled(!enhancementService.isEnhancementEnabled)
                    
                    // Enhancement Prompts Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enhancement Prompt")
                            .font(.headline)
                        
                        PromptSelectionGrid(
                            prompts: enhancementService.allPrompts,
                            selectedPromptId: enhancementService.selectedPromptId,
                            onPromptSelected: { prompt in
                                enhancementService.setActivePrompt(prompt)
                            },
                            onEditPrompt: { prompt in
                                selectedPromptForEdit = prompt
                            },
                            onDeletePrompt: { prompt in
                                enhancementService.deletePrompt(prompt)
                            },
                            onAddNewPrompt: {
                                isEditingPrompt = true
                            }
                        )
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    .disabled(!enhancementService.isEnhancementEnabled)
                    
                    // Context Packs Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Bound Context Packs")
                                .font(.headline)
                            
                            InfoTip(
                                title: "Context Packs",
                                message: "Select context packs to include their dictionary terms and project knowledge in the post-processing pipeline.",
                                learnMoreURL: nil
                            )
                        }
                        
                        if contextPacks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                
                                Text("No Context Packs Available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Create context packs in the Projects section to make them available for post-processing.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
                            ], spacing: 16) {
                                ForEach(contextPacks) { pack in
                                    ContextPackCard(
                                        pack: pack,
                                        isSelected: selectedPackIds.contains(pack.id),
                                        onToggle: { togglePack(pack) }
                                    )
                                }
                            }
                            
                            HStack {
                                Text("\(selectedPackIds.count) packs selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if !selectedPackIds.isEmpty {
                                    Button("Clear Selection") {
                                        selectedPackIds.removeAll()
                                        updateBoundPacks()
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    .disabled(!enhancementService.isEnhancementEnabled)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $isEditingPrompt) {
            PromptEditorView(mode: .add)
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            PromptEditorView(mode: .edit(prompt))
        }
        .onAppear {
            // Load bound pack IDs
            selectedPackIds = Set(boundPackIds)
        }
    }
    
    private func togglePack(_ pack: ContextPack) {
        if selectedPackIds.contains(pack.id) {
            selectedPackIds.remove(pack.id)
        } else {
            selectedPackIds.insert(pack.id)
        }
        updateBoundPacks()
    }
    
    private func updateBoundPacks() {
        boundPackIds = Array(selectedPackIds)
    }
}

// MARK: - Context Pack Card
struct ContextPackCard: View {
    let pack: ContextPack
    let isSelected: Bool
    let onToggle: () -> Void
    
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
                
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            HStack {
                // Pack status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(pack.isActive ? .green : .orange)
                        .frame(width: 6, height: 6)
                    
                    Text(pack.isActive ? "Active" : "Inactive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Term count
                Text("\(pack.termCount) terms")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Project name if available
            if let project = pack.project {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(project.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor), lineWidth: isSelected ? 0 : 1)
        )
        .onTapGesture {
            onToggle()
        }
    }
}
