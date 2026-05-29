import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let coordinator = RenameCoordinator()
    private var settingsWindow: NSWindow?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars",
                                   accessibilityDescription: "AutoRename")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Rename Finder Selection",
                     action: #selector(renameFinderSelection), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Open Drop Window…",
                     action: #selector(openDropWindow), keyEquivalent: "d").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AutoRename",
                     action: #selector(quit), keyEquivalent: "q").target = self
        return menu
    }

    @objc private func renameFinderSelection() {
        let urls = FinderSelection.current()
        guard !urls.isEmpty else {
            notify("No files selected in Finder.")
            return
        }
        coordinator.start(urls: urls)
    }

    @objc private func openDropWindow() {
        coordinator.openEmptyDropWindow()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow.make()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func notify(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "AutoRename"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
