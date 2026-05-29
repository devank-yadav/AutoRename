import AppKit
import SwiftUI

/// Owns the preview and drop windows and routes incoming file URLs into them.
@MainActor
final class RenameCoordinator {
    private var windows: Set<NSWindow> = []

    func start(urls: [URL]) {
        let window = makeWindow(title: "AutoRename — \(urls.count) file(s)", size: NSSize(width: 640, height: 420))
        let view = PreviewView(urls: urls) { [weak self, weak window] in
            if let window { self?.close(window) }
        }
        window.contentViewController = NSHostingController(rootView: view)
        present(window)
    }

    func openEmptyDropWindow() {
        let window = makeWindow(title: "AutoRename", size: NSSize(width: 360, height: 220))
        let view = DropView { [weak self, weak window] urls in
            if let window { self?.close(window) }
            self?.start(urls: urls)
        }
        window.contentViewController = NSHostingController(rootView: view)
        present(window)
    }

    private func makeWindow(title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    private func present(_ window: NSWindow) {
        windows.insert(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close(_ window: NSWindow) {
        window.orderOut(nil)
        windows.remove(window)
    }
}
