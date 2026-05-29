import Foundation
import Security

/// User preferences (UserDefaults) plus the Claude API key (Keychain).
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let keychainService = "com.devank.autorename"
    private let keychainAccount = "openai-api-key"

    private enum Keys {
        static let template = "namingTemplate"
        static let maxLength = "maxLength"
        static let prependDate = "prependDate"
        static let caseStyle = "caseStyle"
        static let language = "language"
    }

    private init() {
        defaults.register(defaults: [
            Keys.template: "{slug}",
            Keys.maxLength: 60,
            Keys.prependDate: false,
            Keys.caseStyle: CaseStyle.kebab.rawValue,
            Keys.language: "English",
        ])
    }

    // MARK: Preferences

    var template: String {
        get { defaults.string(forKey: Keys.template) ?? "{slug}" }
        set { defaults.set(newValue, forKey: Keys.template) }
    }

    var maxLength: Int {
        get { defaults.integer(forKey: Keys.maxLength) }
        set { defaults.set(newValue, forKey: Keys.maxLength) }
    }

    var prependDate: Bool {
        get { defaults.bool(forKey: Keys.prependDate) }
        set { defaults.set(newValue, forKey: Keys.prependDate) }
    }

    var caseStyle: CaseStyle {
        get { CaseStyle(rawValue: defaults.string(forKey: Keys.caseStyle) ?? "") ?? .kebab }
        set { defaults.set(newValue.rawValue, forKey: Keys.caseStyle) }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? "English" }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    // MARK: API key

    /// Resolution order: the user's own key (Keychain → key file) wins, and we
    /// fall back to a key embedded in the app bundle at package time so the app
    /// works out of the box without the user supplying one.
    var apiKey: String? {
        get { readKeychain() ?? readKeyFile() ?? embeddedKey() }
        set {
            if let newValue, !newValue.isEmpty { writeKeychain(newValue); writeKeyFile(newValue) }
            else { deleteKeychain(); deleteKeyFile() }
        }
    }

    /// True when no user key is set and the app is running on the bundled key.
    var usingEmbeddedKey: Bool {
        readKeychain() == nil && readKeyFile() == nil && embeddedKey() != nil
    }

    /// Reads a key injected into Contents/Resources/embedded-key.txt by package.sh.
    private func embeddedKey() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded-key", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Plain-text fallback so the key can be pasted into a file. Lives at
    /// ~/Library/Application Support/AutoRename/api_key.txt
    var keyFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AutoRename/api_key.txt")
    }

    private func readKeyFile() -> String? {
        guard let raw = try? String(contentsOf: keyFileURL, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func writeKeyFile(_ value: String) {
        let url = keyFileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? value.write(to: url, atomically: true, encoding: .utf8)
    }

    private func deleteKeyFile() {
        try? FileManager.default.removeItem(at: keyFileURL)
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: keychainAccount]
    }

    private func readKeychain() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeKeychain(_ value: String) {
        let data = Data(value.utf8)
        SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychain() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}

enum CaseStyle: String, CaseIterable {
    case kebab        // team-standup-notes
    case snake        // team_standup_notes
    case title        // Team Standup Notes
    case lower        // team standup notes

    var label: String {
        switch self {
        case .kebab: return "kebab-case"
        case .snake: return "snake_case"
        case .title: return "Title Case"
        case .lower: return "lower case"
        }
    }
}
