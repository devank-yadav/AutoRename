import AppKit

/// Reads the files currently selected in Finder via Apple Events.
/// Requires the user to grant Automation permission for Finder on first use.
enum FinderSelection {
    static func current() -> [URL] {
        let source = """
        tell application "Finder"
            set sel to selection as alias list
            set out to ""
            repeat with f in sel
                set out to out & POSIX path of f & linefeed
            end repeat
            return out
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return [] }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("FinderSelection AppleScript error: \(error)")
            return []
        }
        let joined = result.stringValue ?? ""
        return joined
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }
}
