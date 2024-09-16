import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    var body: some View {
        TabView {
            ModelSettingsView(selectedModel: $settingsStore.selectedModel, groqAPIKey: $settingsStore.groqAPIKey)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
            
            HotkeySettingsView(recordingHotkey: $settingsStore.recordingHotkey, spotlightChatHotkey: $settingsStore.spotlightChatHotkey)
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
            
            BehaviorSettingsView(autoInsert: $settingsStore.autoInsert, showOverlay: $settingsStore.showOverlay, improveGrammar: $settingsStore.improveGrammar)
                .tabItem {
                    Label("Behavior", systemImage: "gearshape")
                }
        }
        .frame(width: 375, height: 300)
        .padding()
    }
}

struct ModelSettingsView: View {
    @Binding var selectedModel: String
    @Binding var groqAPIKey: String
    
    let models = ["Groq", "OpenAI", "Anthropic"] // Add more models as needed
    
    var body: some View {
        Form {
            Picker("Select Model", selection: $selectedModel) {
                ForEach(models, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(PopUpButtonPickerStyle())
            
            if selectedModel == "Groq" {
                SecureField("Groq API Key", text: $groqAPIKey)
                Text("If not set, the app will use the GROQ_API_KEY environment variable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // Add similar sections for other models when selected
        }
        .padding(10)
    }
}

struct HotkeySettingsView: View {
    @Binding var recordingHotkey: String
    @Binding var spotlightChatHotkey: String
    
    var body: some View {
        Form {
            TextField("Recording Hotkey", text: $recordingHotkey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("Current recording hotkey: \(recordingHotkey)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("Spotlight Chat Hotkey", text: $spotlightChatHotkey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("Current Spotlight chat hotkey: \(spotlightChatHotkey)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Click to record a new hotkey")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
    }
}

struct BehaviorSettingsView: View {
    @Binding var autoInsert: Bool
    @Binding var showOverlay: Bool
    @Binding var improveGrammar: Bool
    
    var body: some View {
        Form {
            Toggle("Auto-insert transcribed text", isOn: $autoInsert)
            Toggle("Show overlay during recording", isOn: $showOverlay)
            Toggle("Improve grammar", isOn: $improveGrammar)
        }
        .padding(10)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settingsStore: SettingsStore())
    }
}
