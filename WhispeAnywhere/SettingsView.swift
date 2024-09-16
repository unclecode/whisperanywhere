import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    var body: some View {
        TabView {
            ModelSettingsView(selectedModel: $settingsStore.selectedModel, groqAPIKey: $settingsStore.groqAPIKey)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
            
            HotkeySettingsView(hotkey: $settingsStore.hotkey)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }
            
            BehaviorSettingsView(autoInsert: $settingsStore.autoInsert, showOverlay: $settingsStore.showOverlay, improveGrammar: $settingsStore.improveGrammar)
                .tabItem {
                    Label("Behavior", systemImage: "gearshape")
                }
        }
        .frame(width: 375, height: 250)
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
    @Binding var hotkey: String
    
    var body: some View {
        Form {
            TextField("Hotkey", text: $hotkey)
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
