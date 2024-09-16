import SwiftUI
import MarkdownUI
import Combine

struct SpotlightChatView: View {
    @Binding var isVisible: Bool
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var isProcessing = false
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var cancellables = Set<AnyCancellable>()
    
    let groqAPI: GroqAPI
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages) { _, _ in
                    withAnimation {
                        scrollView.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask me anything...", text: $inputText, onCommit: sendMessage)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(inputText.isEmpty || isLoading || isProcessing)
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(PlainButtonStyle())
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear(perform: loadChatHistory)
        .background(
            KeyPressBroadcaster { keyCode in
                if keyCode == 53 { // 53 is the key code for the Escape key
                    dismissView()
                }
            }
            .focusable(true)  // Make the KeyPressBroadcaster focusable
        )
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        if isProcessing { return } // Prevent multiple calls
        isProcessing = true
        Logger.log("sendMessage called with inputText: \(inputText)")
        
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        isLoading = true
        Logger.log("Message sent: \(userMessage)")
        
        groqAPI.chat(messages: messages) { result in
            DispatchQueue.main.async {
                isLoading = false
                isProcessing = false // Reset flag after processing
                switch result {
                case .success(let response):
                    Logger.log("Received response: \(response)")
                    let aiMessage = ChatMessage(content: response, isUser: false)
                    messages.append(aiMessage)
                    saveChatHistory()
                case .failure(let error):
                    Logger.log("Error in chat: \(error.localizedDescription)")
                    let errorMessage = ChatMessage(content: "Sorry, there was an error processing your request.", isUser: false)
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    private func clearChat() {
        Logger.log("clearChat called")
        messages.removeAll()
        // Remove chat history from UserDefaults
        UserDefaults.standard.removeObject(forKey: "chatHistory")
        // Log the action
        Logger.log("Chat history cleared")
    }
    
    private func saveChatHistory() {
        Logger.log("saveChatHistory called")
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: "chatHistory")
            Logger.log("Chat history saved")
        } catch {
            Logger.log("Error saving chat history: \(error.localizedDescription)")
        }
    }
    
    private func loadChatHistory() {
        Logger.log("loadChatHistory called")
        guard let data = UserDefaults.standard.data(forKey: "chatHistory") else {
            Logger.log("No chat history found in UserDefaults")
            return
        }
        do {
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            Logger.log("Chat history loaded")
        } catch {
            Logger.log("Error loading chat history: \(error.localizedDescription)")
        }
    }
    
    private func dismissView() {
        Logger.log("dismissView called")
        isVisible = false
    }
}









// Marker: New


struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Markdown(message.content)
                    .markdownTheme(.basic)
                    .textSelection(.enabled)
            }
            .padding()
            .background(message.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
            .cornerRadius(10)
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id && lhs.content == rhs.content && lhs.isUser == rhs.isUser
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct KeyPressBroadcaster: NSViewRepresentable {
    let onKeyDown: (UInt16) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)  // Ensure view becomes the first responder
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyView: NSView {
        var onKeyDown: ((UInt16) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.window?.makeFirstResponder(self)  // Request to become first responder
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event.keyCode)
        }
    }
}

