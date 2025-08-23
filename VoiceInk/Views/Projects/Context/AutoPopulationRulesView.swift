import SwiftUI
import SwiftData

struct AutoPopulationRulesView: View {
    let project: Project
    @State private var showingRuleEditor = false
    @State private var selectedRule: AutoPopulationRule?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Header
                sectionHeader
                
                // Auto-population Rules
                rulesSection
                
                // Smart Content Enrichment
                smartEnrichmentSection
                
                // Pattern-based Organization
                patternOrganizationSection
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingRuleEditor) {
            AutoPopulationRuleEditor(project: project, rule: selectedRule)
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-population Rules")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Configure smart content enrichment and automatic context pack generation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Create Rule") {
                    selectedRule = nil
                    showingRuleEditor = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Rules Section
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Auto-population Rules")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Define rules for automatically generating and updating context packs based on repository changes.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Placeholder for rules list
            VStack(spacing: 12) {
                RuleCard(
                    title: "Git Commit Analysis",
                    description: "Automatically analyze commit messages and changed files to suggest context updates",
                    isEnabled: false,
                    trigger: "On commit",
                    action: "Update relevant context packs"
                ) {
                    // TODO: Configure git commit analysis rule
                }
                
                RuleCard(
                    title: "New File Detection",
                    description: "Detect new documentation files and suggest adding them to appropriate context packs",
                    isEnabled: true,
                    trigger: "File system events",
                    action: "Suggest pack additions"
                ) {
                    // TODO: Configure new file detection rule
                }
                
                RuleCard(
                    title: "Documentation Updates",
                    description: "Monitor README and documentation changes to keep context packs current",
                    isEnabled: true,
                    trigger: "Documentation changes",
                    action: "Auto-refresh packs"
                ) {
                    // TODO: Configure documentation update rule
                }
            }
        }
    }
    
    // MARK: - Smart Enrichment Section
    
    private var smartEnrichmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Content Enrichment")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("AI-powered suggestions for improving context pack quality and relevance.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                EnrichmentCard(
                    icon: "brain.head.profile",
                    title: "Term Extraction",
                    subtitle: "AI-powered technical term identification",
                    status: "Available",
                    color: .blue
                ) {
                    // TODO: Configure term extraction
                }
                
                EnrichmentCard(
                    icon: "link",
                    title: "Relationship Detection",
                    subtitle: "Identify connections between concepts",
                    status: "Coming Soon",
                    color: .purple
                ) {
                    // TODO: Configure relationship detection
                }
                
                EnrichmentCard(
                    icon: "star",
                    title: "Quality Scoring",
                    subtitle: "Automatically score content relevance",
                    status: "Beta",
                    color: .orange
                ) {
                    // TODO: Configure quality scoring
                }
                
                EnrichmentCard(
                    icon: "wand.and.stars",
                    title: "Context Suggestions",
                    subtitle: "Smart recommendations for pack improvements",
                    status: "Coming Soon",
                    color: .green
                ) {
                    // TODO: Configure context suggestions
                }
            }
        }
    }
    
    // MARK: - Pattern Organization Section
    
    private var patternOrganizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pattern-based Organization")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Organize content automatically based on file patterns, project structure, and naming conventions.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                PatternRuleCard(
                    title: "Component Organization",
                    pattern: "**/*Component.swift",
                    action: "Group UI components",
                    packName: "UI Components",
                    isEnabled: true
                )
                
                PatternRuleCard(
                    title: "Service Layer",
                    pattern: "**/*Service.swift",
                    action: "Group business logic",
                    packName: "Services",
                    isEnabled: true
                )
                
                PatternRuleCard(
                    title: "Model Definitions",
                    pattern: "**/Models/*.swift",
                    action: "Group data models",
                    packName: "Data Models",
                    isEnabled: false
                )
                
                PatternRuleCard(
                    title: "Documentation",
                    pattern: "**/*.md",
                    action: "Group documentation",
                    packName: "Documentation",
                    isEnabled: true
                )
            }
            
            Button("Add Custom Pattern") {
                selectedRule = nil
                showingRuleEditor = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Supporting Views

struct RuleCard: View {
    let title: String
    let description: String
    let isEnabled: Bool
    let trigger: String
    let action: String
    let onConfigure: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("", isOn: .constant(isEnabled))
                        .toggleStyle(SwitchToggleStyle())
                    
                    Button("Configure") {
                        onConfigure()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trigger")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(trigger)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Action")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(action)
                        .font(.caption)
                        .fontWeight(.medium)
                }
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

struct EnrichmentCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String
    let color: Color
    let onConfigure: () -> Void
    
    var statusColor: Color {
        switch status {
        case "Available": return .green
        case "Beta": return .orange
        case "Coming Soon": return .secondary
        default: return .secondary
        }
    }
    
    var body: some View {
        Button(action: onConfigure) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor.opacity(0.2))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .stroke(status == "Available" ? color.opacity(0.3) : Color(.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(status == "Coming Soon")
    }
}

struct PatternRuleCard: View {
    let title: String
    let pattern: String
    let action: String
    let packName: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(isEnabled))
                        .toggleStyle(SwitchToggleStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Pattern:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(pattern)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Action:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(action)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Text("→")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(packName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

// Placeholder for rule editor
struct AutoPopulationRuleEditor: View {
    let project: Project
    let rule: AutoPopulationRule?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Auto-population Rule Editor")
                    .font(.title)
                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle(rule == nil ? "Create Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// Placeholder model for auto-population rules
struct AutoPopulationRule: Identifiable {
    let id = UUID()
    let name: String
    let trigger: String
    let action: String
    let isEnabled: Bool
}

#Preview {
    AutoPopulationRulesView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}