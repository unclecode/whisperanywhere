import SwiftUI

class SettingsStore: ObservableObject {
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var groqAPIKey: String {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groqAPIKey") }
    }
    @Published var hotkey: String {
        didSet { UserDefaults.standard.set(hotkey, forKey: "hotkey") }
    }
    @Published var autoInsert: Bool {
        didSet { UserDefaults.standard.set(autoInsert, forKey: "autoInsert") }
    }
    @Published var showOverlay: Bool {
        didSet { UserDefaults.standard.set(showOverlay, forKey: "showOverlay") }
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "Groq"
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.hotkey = UserDefaults.standard.string(forKey: "hotkey") ?? "Cmd+Shift+K"
        self.autoInsert = UserDefaults.standard.bool(forKey: "autoInsert") || true  // Default to true
        self.showOverlay = UserDefaults.standard.bool(forKey: "showOverlay") || true  // Default to true
    }
}
