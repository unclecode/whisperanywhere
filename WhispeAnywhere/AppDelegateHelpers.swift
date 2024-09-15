import Cocoa
import AVFoundation

class AppDelegateHelpers {
    static func checkMicrophoneUsageDescription() {
        if let usageDescription = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String {
            print("Microphone Usage Description: \(usageDescription)")
        } else {
            print("WARNING: NSMicrophoneUsageDescription not found in Info.plist")
        }
    }
    
    static func showMicrophoneAccessDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Denied"
        alert.informativeText = "WhisperAnywhere needs access to your microphone to function properly. Please grant microphone access in System Preferences > Security & Privacy > Privacy > Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    }
    
    static func checkAccessibilityPermissions() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "To automatically insert text, WhisperAnywhere needs accessibility permissions. Please grant these permissions in System Preferences > Security & Privacy > Privacy > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    }
    
    static func showTranscriptionErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Transcription Error"
        alert.informativeText = "An error occurred during transcription: \(error.localizedDescription)"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
