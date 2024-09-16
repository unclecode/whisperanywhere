import SwiftUI

struct SpotlightChatView: View {
    @Binding var isVisible: Bool
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Type your message...", text: $inputText, onCommit: sendMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        isLoading = true
        
        // TODO: Implement API call to language model
        // For now, we'll just simulate a response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = ChatMessage(content: "This is a simulated AI response to: \(userInput)", isUser: false)
            messages.append(aiResponse)
            isLoading = false
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            Text(message.content)
                .padding()
                .background(message.isUser ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct SpotlightChatView_Previews: PreviewProvider {
    static var previews: some View {
        SpotlightChatView(isVisible: .constant(true))
    }
}
