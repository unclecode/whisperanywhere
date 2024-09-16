import Foundation

class GroqAPI {
    private let apiKey: String
    private let baseURL = "https://api.groq.com/openai/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        Logger.log("GroqAPI initialized with API key: \(apiKey)")
    }
    
    func transcribe(audioFileURL: URL, improveGrammar: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        Logger.log("Starting transcription for audio file: \(audioFileURL.lastPathComponent)")
        
        let transcriptionURL = URL(string: baseURL + "/audio/transcriptions")!
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try! Data(contentsOf: audioFileURL))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("distil-whisper-large-v3-en\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        Logger.log("Sending transcription request to Groq API")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Function to remove the audio file
            let removeAudioFile = {
                do {
                    try FileManager.default.removeItem(at: audioFileURL)
                    Logger.log("Audio file removed successfully: \(audioFileURL.lastPathComponent)")
                } catch {
                    Logger.log("Error removing audio file: \(error.localizedDescription)")
                }
            }
            
            if let error = error {
                Logger.log("Error during API request: \(error.localizedDescription)")
                removeAudioFile()
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                Logger.log("No data received from API")
                removeAudioFile()
                completion(.failure(NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let text = json["text"] as? String {
                    Logger.log("Transcription successful. Received text of length: \(text.count)")
                    removeAudioFile()
                    
                    if improveGrammar {
                        self?.improveGrammar(text: text, completion: completion)
                    } else {
                        completion(.success(text))
                    }
                } else {
                    throw NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                Logger.log("Error parsing API response: \(error.localizedDescription)")
                removeAudioFile()
                completion(.failure(error))
            }
        }.resume()
    }
    
    func improveGrammar(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        Logger.log("Starting grammar improvement for text of length: \(text.count)")
        
        let chatCompletionURL = URL(string: baseURL + "/chat/completions")!
        var request = URLRequest(url: chatCompletionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "messages": [
                ["role": "system", "content": "Your task is to improve grammatically for a given text, and return in JSON, following this format:\n\n{\"result\": \"[edited text]\"}"],
                ["role": "user", "content": "\nText to edit: \(text)"]
            ],
            "model": "llama-3.1-8b-instant",
            "temperature": 1,
            "max_tokens": 1024,
            "top_p": 1,
            "stream": false,
            "response_format": ["type": "json_object"],
            "stop": NSNull()
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        Logger.log("Sending grammar improvement request to Groq API")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.log("Error during API request: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                Logger.log("No data received from API")
                completion(.failure(NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let contentData = content.data(using: .utf8),
                   let contentJson = try JSONSerialization.jsonObject(with: contentData, options: []) as? [String: String],
                   let improvedText = contentJson["result"] {
                    Logger.log("Grammar improvement successful. Received improved text of length: \(improvedText.count)")
                    completion(.success(improvedText))
                } else {
                    throw NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                Logger.log("Error parsing API response: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func chat(messages: [ChatMessage], completion: @escaping (Result<String, Error>) -> Void) {
        Logger.log("Starting chat with \(messages.count) messages")
        
        let chatCompletionURL = URL(string: baseURL + "/chat/completions")!
        var request = URLRequest(url: chatCompletionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiMessages = [["role": "system", "content": "You are a helpful assistant answering questions that the user is asking."]] +
            messages.map { ["role": $0.isUser ? "user" : "assistant", "content": $0.content] }
        
        let requestBody: [String: Any] = [
            "messages": apiMessages,
            "model": "llama-3.1-8b-instant",
            "temperature": 0.7,
            "max_tokens": 1024,
            "top_p": 1,
            "stream": false,
            "stop": NSNull()
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        Logger.log("Sending chat request to Groq API")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.log("Error during API request: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                Logger.log("No data received from API")
                completion(.failure(NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    Logger.log("Chat response received. Length: \(content.count)")
                    completion(.success(content))
                } else {
                    throw NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                Logger.log("Error parsing API response: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}
