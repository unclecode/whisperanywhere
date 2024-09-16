import Cocoa
import SwiftUI
import Carbon
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, HotkeyManagerDelegate {
    var statusBarController: StatusBarController?
    var hotkeyManager: HotkeyManager?
    var audioRecorder: AudioRecorder?
    var overlayWindow: OverlayWindow?
    var groqAPI: GroqAPI?
    var settingsWindowController: NSWindowController?
    let settingsStore = SettingsStore()
    var overlayUpdateTimer: Timer?
    private var logViewerWindow: LogViewerWindow?
    
    var spotlightChatWindow: NSWindow?
    @Published var isSpotlightChatVisible = false
    
    @AppStorage("selectedModel") var selectedModel = "Groq"
    @AppStorage("groqAPIKey") var groqAPIKey = ""
    @AppStorage("hotkey") var hotkey = "Cmd+Shift+K"
    @AppStorage("autoInsert") var autoInsert = true
    @AppStorage("showOverlay") var showOverlay = true
    
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.log("Application did finish launching")
        setupErrorHandling()
        AppDelegateHelpers.checkMicrophoneUsageDescription()
        setupComponents()
    }
    
    private func setupErrorHandling() {
        NSSetUncaughtExceptionHandler { exception in
            Logger.log("Uncaught exception: \(exception)")
            Logger.log("Call stack: \(exception.callStackSymbols)")
        }
    }
    
    private func setupComponents() {
        Logger.log("Setting up components")
        setupStatusBar()
        setupHotkey()
        setupAudioRecorder()
        setupOverlayWindow()
        setupGroqAPI()
        setupSpotlightChat()
        startOverlayUpdateTimer()
    }
    
    private func setupStatusBar() {
        statusBarController = StatusBarController()
        statusBarController?.onPreferencesClicked = { [weak self] in
            self?.showSettings()
        }
        statusBarController?.onStartStopRecording = { [weak self] in
            self?.toggleRecording()
        }
        
        // Add this new line to handle the log viewer
        statusBarController?.showLogWindow = { [weak self] in
            self?.showLogViewer()
        }
        
        Logger.log("Status bar setup completed")
    }

    // Add this new method to your AppDelegate class
    private func showLogViewer() {
        if logViewerWindow == nil {
            logViewerWindow = LogViewerWindow()
        }
        logViewerWindow?.updateLogContent()
        logViewerWindow?.makeKeyAndOrderFront(nil)
    }
    
    
    private func setupSpotlightChat() {
        let contentView = SpotlightChatView(isVisible: Binding<Bool>(
            get: { self.isSpotlightChatVisible },
            set: { self.isSpotlightChatVisible = $0 }
        ), groqAPI: self.groqAPI!)
        
            spotlightChatWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
//                styleMask: [ .borderless],
                backing: .buffered,
                defer: false)
        
           // Make the window transparent and non-opaque
           spotlightChatWindow?.backgroundColor = .clear
           spotlightChatWindow?.isOpaque = false
           
           // Ensure the content view fills the entire window
           spotlightChatWindow?.styleMask.insert(.fullSizeContentView)
           
           spotlightChatWindow?.center()
           spotlightChatWindow?.setFrameAutosaveName("SpotlightChat")
           spotlightChatWindow?.contentView = NSHostingView(rootView: contentView)
           spotlightChatWindow?.isReleasedWhenClosed = false
           spotlightChatWindow?.level = .floating
        }
        
    private func toggleSpotlightChat() {
        if isSpotlightChatVisible {
            spotlightChatWindow?.close()
            isSpotlightChatVisible = false
        } else {
            spotlightChatWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Make sure the window and content get focus
            spotlightChatWindow?.makeFirstResponder(spotlightChatWindow?.contentView)
            
            isSpotlightChatVisible = true
        }
    }
    
    private func setupHotkey() {
            hotkeyManager = HotkeyManager(settingsStore: settingsStore, delegate: self)
        }
        
        func hotkeyTriggered(for action: String) {
            switch action {
            case "toggleRecording":
                toggleRecording()
            case "showSpotlightChat":
                toggleSpotlightChat()
            default:
                break
            }
        }
    
    
    private func setupAudioRecorder() {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        Logger.log("Microphone access granted")
                        self?.audioRecorder = AudioRecorder()
                    } else {
                        Logger.log("Microphone access denied")
                        AppDelegateHelpers.showMicrophoneAccessDeniedAlert()
                    }
                }
            }
        }
    
    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow()
    }
    
    private func setupGroqAPI() {
        let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? settingsStore.groqAPIKey
        groqAPI = GroqAPI(apiKey: apiKey)
        Logger.log("GroqAPI setup completed")
    }
    
    private func startOverlayUpdateTimer() {
        overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition()
        }
    }
    
    private func updateOverlayPosition() {
        guard let overlayWindow = overlayWindow, overlayWindow.isVisible else { return }
        overlayWindow.updatePosition(with: NSEvent.mouseLocation)
    }
    
    func toggleRecording() {
        if let audioRecorder = audioRecorder, audioRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
            audioRecorder?.startRecording { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        Logger.log("Recording started successfully")
                        self?.updateOverlayStatus(.recording)
                        self?.showOverlayAtMousePosition()
                    } else {
                        Logger.log("Failed to start recording")
                        self?.updateOverlayStatus(.error)
                    }
                }
            }
        }
    
    private func stopRecording() {
            audioRecorder?.stopRecording { [weak self] url in
                DispatchQueue.main.async {
                    if let url = url {
                        Logger.log("Recording stopped, processing audio file: \(url.lastPathComponent)")
                        self?.updateOverlayStatus(.processing)
                        self?.processAudio(url: url)
                    } else {
                        Logger.log("Failed to stop recording or no audio file produced")
                        self?.updateOverlayStatus(.error)
                    }
                }
            }
        }
    
    private func processAudio(url: URL) {
            Logger.log("Processing audio file: \(url.lastPathComponent)")
            groqAPI?.transcribe(audioFileURL: url, improveGrammar: settingsStore.improveGrammar) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription):
                        Logger.log("Transcription successful")
                        self?.handleSuccessfulTranscription(transcription)
                    case .failure(let error):
                        Logger.log("Transcription failed: \(error.localizedDescription)")
                        self?.handleTranscriptionError(error)
                    }
                }
            }
        }
        
    private func handleSuccessfulTranscription(_ transcription: String) {
        Logger.log("Handling successful transcription")
        updateOverlayStatus(.done)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hideOverlay()
            ClipboardManager.shared.copyToClipboard(transcription)
            if self.settingsStore.autoInsert {
                if AppDelegateHelpers.checkAccessibilityPermissions() {
                    Logger.log("Auto-inserting transcription")
                    ClipboardManager.shared.insertText(transcription)
                } else {
                    Logger.log("Accessibility permissions not granted, prompting user")
                    self.promptForAccessibilityPermissions()
                }
            } else {
                Logger.log("Transcription copied to clipboard")
            }
        }
    }
    
    private func promptForAccessibilityPermissions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "To auto-insert text, this app needs accessibility permissions. Would you like to open System Preferences to grant these permissions?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func handleTranscriptionError(_ error: Error) {
        Logger.log("Handling transcription error: \(error.localizedDescription)")
        updateOverlayStatus(.error)
        AppDelegateHelpers.showTranscriptionErrorAlert(error: error)
    }
    
    private func updateOverlayStatus(_ status: RecordingStatus) {
        if showOverlay {
            overlayWindow?.updateStatus(status)
        }
    }
    
    private func showOverlayAtMousePosition() {
        guard settingsStore.showOverlay, let overlayWindow = overlayWindow else { return }
        overlayWindow.updatePosition(with: NSEvent.mouseLocation)
        overlayWindow.makeKeyAndOrderFront(nil)
    }
    
    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
    
    func showSettings() {
            if settingsWindowController == nil {
                let contentView = SettingsView(settingsStore: self.settingsStore)
                let window = NSWindow(
                    contentRect: NSRect(x: 20, y: 20, width: 375, height: 250),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false)
                window.center()
                window.setFrameAutosaveName("Settings")
                window.contentView = NSHostingView(rootView: contentView)
                window.title = "Settings"
                window.level = .floating
                window.isMovableByWindowBackground = true
                settingsWindowController = NSWindowController(window: window)
            }
            settingsWindowController?.showWindow(nil)
            settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        }
}
