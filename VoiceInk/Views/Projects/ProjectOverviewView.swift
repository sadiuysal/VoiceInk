import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProjectOverviewView: View {
    let project: Project
    @StateObject private var contextStore = ContextIndexStore.shared

    @Environment(\.modelContext) private var modelContext
    
    private var totalTerms: Int {
        project.packs.reduce(0) { $0 + $1.termCount }
    }
    
    private var activePacks: Int {
        project.packs.filter { $0.isActive }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Project Overview")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Project Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Project Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatisticCard(
                                title: "Sources",
                                value: "\(project.sources.count)",
                                icon: "folder.badge.gearshape",
                                color: .blue
                            )
                            
                            StatisticCard(
                                title: "Context Packs",
                                value: "\(project.packs.count)",
                                icon: "brain.head.profile",
                                color: .purple
                            )
                            
                            StatisticCard(
                                title: "Dictionary Terms",
                                value: "\(totalTerms)",
                                icon: "character.book.closed",
                                color: .green
                            )
                            
                            StatisticCard(
                                title: "Active Packs",
                                value: "\(activePacks)",
                                icon: "checkmark.circle.fill",
                                color: .orange
                            )
                        }
                    }
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            if let lastSync = project.lastSyncDate {
                                ActivityRow(
                                    icon: "arrow.clockwise",
                                    title: "Last Sync",
                                    subtitle: "Project synchronized",
                                    timestamp: lastSync,
                                    color: .blue
                                )
                            }
                            
                            if let updatedPack = project.packs.max(by: { $0.updatedAt < $1.updatedAt }) {
                                ActivityRow(
                                    icon: "brain.head.profile",
                                    title: "Context Pack Updated",
                                    subtitle: updatedPack.name,
                                    timestamp: updatedPack.updatedAt,
                                    color: .purple
                                )
                            }
                            
                            if let latestSource = project.sources.max(by: { $0.createdAt < $1.createdAt }) {
                                ActivityRow(
                                    icon: "folder.badge.gearshape",
                                    title: "Source Added",
                                    subtitle: latestSource.name,
                                    timestamp: latestSource.createdAt,
                                    color: .green
                                )
                            }
                            
                            if project.sources.isEmpty && project.packs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Recent Activity")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Start by adding sources or creating context packs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.controlBackgroundColor))
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
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

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
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

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let timestamp: Date
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProjectOverviewView(project: Project(
        name: "Sample Project",
        projectDescription: "A sample project for preview",
        rootPath: "/path/to/project"
    ))
    .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}