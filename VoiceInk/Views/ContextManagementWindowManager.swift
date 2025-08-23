import SwiftUI
import AppKit

class ContextManagementWindowManager: ObservableObject {
    static let shared = ContextManagementWindowManager()
    
    private var window: NSWindow?
    
    private init() {}
    
    func openContextManagementWindow() {
        // Close existing window if open
        closeWindow()
        
        // Create new window
        let contentView = ContextManagementWindow()
            .environmentObject(self)
            .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Context Management"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        self.window = window
        
        // Bring to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - Context Management Window with Close Support

struct ContextManagementWindowWithClose: View {
    @EnvironmentObject private var windowManager: ContextManagementWindowManager
    
    var body: some View {
        ContextManagementWindow()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        windowManager.closeWindow()
                    }
                }
            }
    }
}

#Preview {
    ContextManagementWindowWithClose()
        .environmentObject(ContextManagementWindowManager.shared)
        .modelContainer(for: [Project.self, ContextSource.self, ContextPack.self])
}
