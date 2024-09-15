import Foundation

class GroqAPI {
    private let apiKey: String
    private let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func transcribe(audioFileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: baseURL)!)
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Function to remove the audio file
            let removeAudioFile = {
                do {
                    try FileManager.default.removeItem(at: audioFileURL)
                    print("Audio file removed successfully")
                } catch {
                    print("Error removing audio file: \(error.localizedDescription)")
                }
            }
            
            if let error = error {
                removeAudioFile()
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                removeAudioFile()
                completion(.failure(NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let text = json["text"] as? String {
                    removeAudioFile()
                    completion(.success(text))
                } else {
                    throw NSError(domain: "GroqAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                removeAudioFile()
                completion(.failure(error))
            }
        }.resume()
    }
}
