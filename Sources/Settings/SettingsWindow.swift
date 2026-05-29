import SwiftUI
import AppKit

enum SettingsWindow {
    static func make() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "AutoRename Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView())
        return window
    }
}

struct SettingsView: View {
    private let settings = SettingsStore.shared
    @State private var apiKey: String = SettingsStore.shared.apiKey ?? ""
    @State private var template: String = SettingsStore.shared.template
    @State private var maxLength: Double = Double(SettingsStore.shared.maxLength)
    @State private var prependDate: Bool = SettingsStore.shared.prependDate
    @State private var caseStyle: CaseStyle = SettingsStore.shared.caseStyle
    @State private var language: String = SettingsStore.shared.language
    @State private var saved = false

    var body: some View {
        Form {
            Section("OpenAI API") {
                SecureField("API key (sk-…)", text: $apiKey)
                Text("Get a key at platform.openai.com. Stored in your Keychain (and a local key file). Only extracted text is ever sent.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Naming") {
                TextField("Template", text: $template)
                Text("Use {slug} for the AI name and {date} for the file date.")
                    .font(.caption).foregroundColor(.secondary)
                Picker("Case", selection: $caseStyle) {
                    ForEach(CaseStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Prepend date", isOn: $prependDate)
                HStack {
                    Text("Max length")
                    Slider(value: $maxLength, in: 20...120, step: 5)
                    Text("\(Int(maxLength))")
                }
                TextField("Language", text: $language)
            }
            HStack {
                Spacer()
                if saved { Text("Saved").font(.caption).foregroundColor(.green) }
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 360)
    }

    private func save() {
        settings.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.template = template.isEmpty ? "{slug}" : template
        settings.maxLength = Int(maxLength)
        settings.prependDate = prependDate
        settings.caseStyle = caseStyle
        settings.language = language.isEmpty ? "English" : language
        saved = true
    }
}
