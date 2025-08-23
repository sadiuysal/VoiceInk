import SwiftUI

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    let isEnabled: Bool
    let showBadge: Bool
    let badgeText: String?
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color = .accentColor,
        isEnabled: Bool = true,
        showBadge: Bool = false,
        badgeText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.isEnabled = isEnabled
        self.showBadge = showBadge
        self.badgeText = badgeText
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                    
                    Spacer()
                    
                    if showBadge, let badgeText = badgeText {
                        Text(badgeText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isHovered ? iconColor.opacity(0.3) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    VStack(spacing: 20) {
        ActionCard(
            title: "Record & Transcribe",
            subtitle: "Start voice recording and get real-time transcription with AI enhancement",
            icon: "mic.circle.fill",
            iconColor: .green
        ) {
            print("Record action")
        }
        
        ActionCard(
            title: "Project Context",
            subtitle: "Manage project sources, Git repositories, and context assembly",
            icon: "folder.badge.gearshape",
            iconColor: .blue,
            showBadge: true,
            badgeText: "2 Active"
        ) {
            print("Projects action")
        }
        
        ActionCard(
            title: "AI Enhancement",
            subtitle: "Configure AI behavior profiles and enhancement settings",
            icon: "wand.and.stars",
            iconColor: .purple
        ) {
            print("Enhancement action")
        }
    }
    .padding(40)
    .background(Color(.windowBackgroundColor))
}
