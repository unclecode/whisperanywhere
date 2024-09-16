import Foundation

class Logger {
    static var printToConsole = true  // Set this to false in release builds if desired
    
    static func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "\(timestamp): \(message)\n"
        
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFileURL = documentsDirectory.appendingPathComponent("app.log")
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logMessage.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try? logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        }
        
        // Print to console if printToConsole is true
        if printToConsole {
            print(logMessage)
        }
    }
    
    static func clearLog() {
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let logFileURL = documentsDirectory.appendingPathComponent("app.log")
                do {
                    try "".write(to: logFileURL, atomically: true, encoding: .utf8)
                    log("Log cleared")
                } catch {
                    log("Failed to clear log: \(error.localizedDescription)")
                }
            }
        }
    
    static func viewLogFile() -> String? {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFileURL = documentsDirectory.appendingPathComponent("app.log")
            return try? String(contentsOf: logFileURL, encoding: .utf8)
        }
        return nil
    }
}
