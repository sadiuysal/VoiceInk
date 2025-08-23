import SwiftUI
import SwiftData

struct BindingConfigurationView: View {
    let project: Project
    @StateObject private var powerModeManager = PowerModeManager.shared
    
    var boundProfiles: [PowerModeConfig] {
        powerModeManager.configurations.filter { profile in
            project.packs.contains { pack in
                profile.boundPackIds.contains(pack.id)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Header
                sectionHeader
                
                // Pack to Profile Bindings
                packProfileBindings
                
                // Usage Statistics
                usageStatistics
                
                // Integration Settings
                integrationSettings
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Binding Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Manage how context packs connect to Power Mode profiles and AI enhancement workflows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Refresh Bindings") {
                    // TODO: Refresh binding information
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Pack to Profile Bindings
    
    private var packProfileBindings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context Pack Bindings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("View and manage which Power Mode profiles use context packs from this project.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if project.packs.isEmpty {
                emptyPacksView
            } else if boundProfiles.isEmpty {
                noBindingsView
            } else {
                bindingsListView
            }
        }
    }
    
    private var emptyPacksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Context Packs")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Create context packs in the Context Packs section to enable binding configuration")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
    
    private var noBindingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Active Bindings")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Context packs from this project are not currently bound to any Power Mode profiles")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Configure in Power Mode") {
                // TODO: Navigate to Power Mode or show instructions
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
    
    private var bindingsListView: some View {
        VStack(spacing: 12) {
            ForEach(boundProfiles, id: \.id) { profile in
                BindingRow(profile: profile, project: project)
            }
        }
    }
    
    // MARK: - Usage Statistics
    
    private var usageStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Statistics")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Analytics and effectiveness metrics for context pack usage (coming soon).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Total Activations", value: "0", icon: "play.circle", color: .blue)
                StatCard(title: "Avg. Enhancement Time", value: "0ms", icon: "clock", color: .green)
                StatCard(title: "Success Rate", value: "0%", icon: "checkmark.circle", color: .orange)
            }
        }
    }
    
    // MARK: - Integration Settings
    
    private var integrationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Integration Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Configure how context packs integrate with AI enhancement workflows.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                SettingRow(
                    title: "Auto-bind New Packs",
                    subtitle: "Automatically bind new context packs to default profile",
                    isEnabled: false
                ) { _ in
                    // TODO: Toggle auto-binding
                }
                
                SettingRow(
                    title: "Priority Ordering",
                    subtitle: "Use pack creation order for binding priority",
                    isEnabled: true
                ) { _ in
                    // TODO: Toggle priority ordering
                }
                
                SettingRow(
                    title: "Context Validation",
                    subtitle: "Validate context pack content before AI enhancement",
                    isEnabled: true
                ) { _ in
                    // TODO: Toggle validation
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
}

// MARK: - Supporting Views

struct BindingRow: View {
    let profile: PowerModeConfig
    let project: Project
    
    private var boundPacks: [ContextPack] {
        project.packs.filter { pack in
            profile.boundPackIds.contains(pack.id)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.emoji)
                            .font(.title2)
                        
                        Text(profile.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Power Mode Profile")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(boundPacks.count) packs")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text(profile.isEnabled ? "Active" : "Inactive")
                        .font(.caption2)
                        .foregroundColor(profile.isEnabled ? .green : .orange)
                }
            }
            
            if !boundPacks.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bound Context Packs")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(boundPacks, id: \.id) { pack in
                            HStack(spacing: 6) {
                                Image(systemName: pack.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(pack.isActive ? .green : .orange)
                                
                                Text(pack.name)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                    }
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct SettingRow: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: onToggle
            ))
            .toggleStyle(SwitchToggleStyle())
        }
    }
}

#Preview {
    BindingConfigurationView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}