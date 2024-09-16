import SwiftUI

class SettingsStore: ObservableObject {
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var groqAPIKey: String {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groqAPIKey") }
    }
    @Published var recordingHotkey: String {
        didSet { UserDefaults.standard.set(recordingHotkey, forKey: "recordingHotkey") }
    }
    @Published var spotlightChatHotkey: String {
        didSet { UserDefaults.standard.set(spotlightChatHotkey, forKey: "spotlightChatHotkey") }
    }
    @Published var autoInsert: Bool {
        didSet { UserDefaults.standard.set(autoInsert, forKey: "autoInsert") }
    }
    @Published var showOverlay: Bool {
        didSet { UserDefaults.standard.set(showOverlay, forKey: "showOverlay") }
    }
    @Published var improveGrammar: Bool {
        didSet { UserDefaults.standard.set(improveGrammar, forKey: "improveGrammar") }
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "Groq"
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.recordingHotkey = UserDefaults.standard.string(forKey: "recordingHotkey") ?? "Option+Shift+K"
        self.spotlightChatHotkey = UserDefaults.standard.string(forKey: "spotlightChatHotkey") ?? "Option+Shift+O"
        self.autoInsert = UserDefaults.standard.bool(forKey: "autoInsert") || true  // Default to true
        self.showOverlay = UserDefaults.standard.bool(forKey: "showOverlay") || true  // Default to true
        self.improveGrammar = UserDefaults.standard.bool(forKey: "improveGrammar") || false  // Default to false
    }
}
