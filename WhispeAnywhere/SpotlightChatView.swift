import SwiftUI
import MarkdownUI
import Combine
import UniformTypeIdentifiers
import AppKit

struct AttachedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: String
}

struct SpotlightChatView: View {
    @Binding var isVisible: Bool
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var isProcessing = false
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var cancellables = Set<AnyCancellable>()
    @FocusState private var isInputFocused: Bool
    @State private var textEditorHeight: CGFloat = 20 // Initial height
    @State private var attachedFiles: [AttachedFile] = []
    @State private var showingClearConfirmation = false
    
    let groqAPI: GroqAPI
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message,
                                        inputText: $inputText,
                                        isFocused: Binding(get: { self.isInputFocused }, set: { self.isInputFocused = $0 }),
                                        textEditorHeight: $textEditorHeight)
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
            
            if !attachedFiles.isEmpty {
                AttachedFilesView(attachedFiles: $attachedFiles)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                AutoSizingTextEditor(text: $inputText, height: $textEditorHeight)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .frame(height: textEditorHeight)
                    .focused($isInputFocused)
                
                Button(action: attachFile) {
                    Image(systemName: "paperclip")
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
                .disabled(inputText.isEmpty && attachedFiles.isEmpty || isLoading || isProcessing)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingClearConfirmation = true }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .alert("Clear Chat History", isPresented: $showingClearConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive, action: clearChat)
                } message: {
                    Text("Are you sure you want to clear the chat history? This action cannot be undone.")
                }
        .onAppear {
            Logger.log("SpotlightChatView appeared")
            loadChatHistory()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
                Logger.log("Input focus set")
            }
            NotificationCenter.default.addObserver(forName: .submitText, object: nil, queue: .main) { _ in
                sendMessage()
            }
        }
        .onDisappear {
            Logger.log("SpotlightChatView disappeared")
        }
    }
    
    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .pdf, .image, .audio, .movie, .data]
        
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    let fileName = url.lastPathComponent
                    let fileType = url.pathExtension
                    let attachedFile = AttachedFile(url: url, name: fileName, type: fileType)
                    attachedFiles.append(attachedFile)
                }
            }
        }
    }
    
  
    
    private func sendMessage() {
            guard !inputText.isEmpty || !attachedFiles.isEmpty else { return }
            if isProcessing { return }
            isProcessing = true
            
            let displayContent = inputText
            var apiContent: String?
            let fileNames = attachedFiles.map { $0.name }
            
            if !attachedFiles.isEmpty {
                apiContent = "<attachments>\n"
                for file in attachedFiles {
                    if let fileContent = try? String(contentsOf: file.url, encoding: .utf8) {
                        apiContent! += " <file name=\"\(file.name)\">\n"
                        apiContent! += "  \(fileContent.replacingOccurrences(of: "\n", with: "\n  "))\n"
                        apiContent! += " </file>\n"
                    } else {
                        Logger.log("Failed to read contents of file: \(file.name)")
                        apiContent! += " <file name=\"\(file.name)\">\n"
                        apiContent! += "  [Failed to read file contents]\n"
                        apiContent! += " </file>\n"
                    }
                }
                apiContent! += "</attachments>\n\n"
                apiContent! += inputText
            }
            
            Logger.log("sendMessage called with displayContent: \(displayContent)")
            if let apiContent = apiContent {
                Logger.log("API Content: \(apiContent)")
            }
            
            let userMessage = ChatMessage(content: displayContent, apiContent: apiContent, isUser: true, attachedFileNames: fileNames)
            messages.append(userMessage)
            inputText = ""  // Clear the input text
            attachedFiles.removeAll()
            isLoading = true
            Logger.log("Message sent: \(userMessage)")
            
            // Send apiContent to Groq API if it exists, otherwise send displayContent
            groqAPI.chat(messages: messages.map { ChatMessage(content: $0.apiContent ?? $0.content, apiContent: $0.apiContent, isUser: $0.isUser, attachedFileNames: $0.attachedFileNames) }) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    isProcessing = false
                    switch result {
                    case .success(let response):
                        Logger.log("Received response: \(response)")
                        let aiMessage = ChatMessage(content: response, apiContent: nil, isUser: false, attachedFileNames: [])
                        messages.append(aiMessage)
                        saveChatHistory()
                    case .failure(let error):
                        Logger.log("Error in chat: \(error.localizedDescription)")
                        let errorMessage = ChatMessage(content: "Sorry, there was an error processing your request.", apiContent: nil, isUser: false, attachedFileNames: [])
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

struct AttachedFilesView: View {
    @Binding var attachedFiles: [AttachedFile]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachedFiles) { file in
                    AttachedFileItemView(file: file) {
                        if let index = attachedFiles.firstIndex(where: { $0.id == file.id }) {
                            attachedFiles.remove(at: index)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .background(Color.gray.opacity(0.1))
    }
}

struct AttachedFileItemView: View {
    let file: AttachedFile
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: iconForFileType(file.type))
                .foregroundColor(Color.gray.opacity(1))
            Text(file.name)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.gray.opacity(1))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.5))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    func iconForFileType(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "mp4", "mov", "avi":
            return "film.fill"
        default:
            return "doc.text.fill"
        }
    }
}

struct AttachedFileLabel: View {
    let fileName: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForFileType(fileName))
                .foregroundColor(Color.gray.opacity(0.8))
            Text(fileName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
    
    func iconForFileType(_ fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "mp4", "mov", "avi":
            return "film.fill"
        default:
            return "doc.text.fill"
        }
    }
}

struct AutoSizingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: textView.frame.size.width, height: .greatestFiniteMagnitude)
        
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        updateHeight(textView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateHeight(_ textView: NSTextView) {
        let newHeight = min(max(textView.bounds.height, 30), 200) // Min 40, Max 200
        if abs(height - newHeight) > 1 {
            DispatchQueue.main.async {
                self.height = newHeight
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoSizingTextEditor
        
        init(_ parent: AutoSizingTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.updateHeight(textView)
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if !NSEvent.modifierFlags.contains(.shift) {
                    // Enter without shift, submit the text
                    NotificationCenter.default.post(name: .submitText, object: nil)
                    return true
                }
            }
            return false
        }
    }
}

extension Notification.Name {
    static let submitText = Notification.Name("submitText")
}


// Marker: New



struct ChatMessageView: View {
    let message: ChatMessage
    @Binding var inputText: String
    @Binding var isFocused: Bool
    @Binding var textEditorHeight: CGFloat
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Message content
            Markdown(message.content)
                .markdownTheme(.basic)
                .textSelection(.enabled)
            
            // Attached files (only for user messages)
            if message.isUser && !message.attachedFileNames.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(message.attachedFileNames, id: \.self) { fileName in
                        AttachedFileLabel(fileName: fileName)
                    }
                }
            }
        }
        .padding()
        .background(message.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                quoteMessage()
            }) {
                Label("Quote", systemImage: "text.quote")
            }
            
            Button(action: {
                shareMessage(message.content)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    private func quoteMessage() {
        let quotedText = "```\n\(message.content)\n```\n\n"
        inputText += quotedText
        isFocused = true
        
        // Adjust the text editor height
        let newHeight = calculateTextViewHeight(for: inputText)
        textEditorHeight = min(max(newHeight, 20), 200) // Min 20, Max 200
        
        // Ensure the cursor is at the end of the new text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let textView = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
                let endRange = NSRange(location: textView.string.count, length: 0)
                textView.scrollRangeToVisible(endRange)
                textView.setSelectedRange(endRange)
            }
        }
    }
    
    private func calculateTextViewHeight(for text: String) -> CGFloat {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 0)) // Assume width of 300
        textView.string = text
        textView.sizeToFit()
        return textView.frame.height
    }
    
    private func shareMessage(_ content: String) {
        let sharingPicker = NSSharingServicePicker(items: [content])
        if let targetView = NSApplication.shared.windows.first?.contentView {
            sharingPicker.show(relativeTo: .zero, of: targetView, preferredEdge: .minY)
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let content: String
    let apiContent: String?
    let isUser: Bool
    let attachedFileNames: [String]  // New property to store attached file names
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id && lhs.content == rhs.content && lhs.apiContent == rhs.apiContent && lhs.isUser == rhs.isUser && lhs.attachedFileNames == rhs.attachedFileNames
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

