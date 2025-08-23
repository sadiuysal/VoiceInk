import SwiftUI
import SwiftData

struct ContextManagementTabView: View {
    let project: Project
    @State private var selectedSection: ContextSection = .contextPacks
    
    enum ContextSection: String, CaseIterable {
        case contextPacks = "Context Packs"
        case sourceManagement = "Source Management"
        case bindingConfiguration = "Binding Configuration"
        case autoPopulation = "Auto-population Rules"
        
        var icon: String {
            switch self {
            case .contextPacks: return "brain.head.profile"
            case .sourceManagement: return "folder.badge.gearshape"
            case .bindingConfiguration: return "link"
            case .autoPopulation: return "wand.and.stars"
            }
        }
        
        var description: String {
            switch self {
            case .contextPacks: return "Create, edit, and manage context packs"
            case .sourceManagement: return "Configure Git repositories, manual notes, and file patterns"
            case .bindingConfiguration: return "Manage pack-to-project relationships and priorities"
            case .autoPopulation: return "Set up smart content enrichment and automatic generation"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Context Management")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Help") {
                        // TODO: Show context management help
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Comprehensive project context management for AI-enhanced development workflows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Section Navigation
            HStack(spacing: 0) {
                ForEach(ContextSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 12))
                                Text(section.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(selectedSection == section ? .accentColor : .secondary)
                            
                            if selectedSection == section {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Section Content
            Group {
                switch selectedSection {
                case .contextPacks:
                    ContextPacksSectionView(project: project)
                case .sourceManagement:
                    SourceManagementSectionView(project: project)
                case .bindingConfiguration:
                    BindingConfigurationView(project: project)
                case .autoPopulation:
                    AutoPopulationRulesView(project: project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContextManagementTabView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}