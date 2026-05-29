import AppKit

// Entry point. swiftc treats main.swift as the program entry; we boot a plain
// AppKit agent app (no Dock icon) and hand control to the AppDelegate.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
