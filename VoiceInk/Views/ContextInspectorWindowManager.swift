import Cocoa
import SwiftUI

final class ContextInspectorWindowManager: NSObject, NSWindowDelegate {
    static let shared = ContextInspectorWindowManager()
    private var window: NSWindow?

    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let controller = NSHostingController(rootView: ContextInspectorView())
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Project Context Inspector"
        win.isReleasedWhenClosed = false
        win.contentViewController = controller
        win.center()
        win.delegate = self
        self.window = win
    }

    func windowWillClose(_ notification: Notification) {
        // Break retain cycles and release the window safely
        window?.contentViewController = nil
        window = nil
    }
}
