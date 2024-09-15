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
    
    
    @AppStorage("selectedModel") var selectedModel = "Groq"
    @AppStorage("groqAPIKey") var groqAPIKey = ""
    @AppStorage("hotkey") var hotkey = "Cmd+Shift+K"
    @AppStorage("autoInsert") var autoInsert = true
    @AppStorage("showOverlay") var showOverlay = true
    
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupErrorHandling()
        AppDelegateHelpers.checkMicrophoneUsageDescription()
        setupComponents()
    }
    
    private func setupErrorHandling() {
        NSSetUncaughtExceptionHandler { exception in
            print("Uncaught exception: \(exception)")
            print("Call stack: \(exception.callStackSymbols)")
        }
    }
    
    private func setupComponents() {
        setupStatusBar()
        setupHotkey()
        setupAudioRecorder()
        setupOverlayWindow()
        setupGroqAPI()
        startOverlayUpdateTimer()
    }
    
    private func setupStatusBar() {
        statusBarController = StatusBarController()
        statusBarController?.onPreferencesClicked = { [weak self] in self?.showSettings() }
        statusBarController?.onStartStopRecording = { [weak self] in self?.toggleRecording() }
    }
    
    private func setupHotkey() {
            print("Setting up hotkey...")
            hotkeyManager = HotkeyManager(settingsStore: settingsStore, delegate: self)
        }
    
    
    func hotkeyTriggered() {
            print("Hotkey triggered, toggling recording")
            toggleRecording()
        }
    
    
    private func setupAudioRecorder() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.audioRecorder = AudioRecorder()
                } else {
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
                    self?.updateOverlayStatus(.recording)
                    self?.showOverlayAtMousePosition()
                } else {
                    self?.updateOverlayStatus(.error)
                }
            }
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stopRecording { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.updateOverlayStatus(.processing)
                    self?.processAudio(url: url)
                } else {
                    self?.updateOverlayStatus(.error)
                }
            }
        }
    }
    
    private func processAudio(url: URL) {
        groqAPI?.transcribe(audioFileURL: url) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self?.handleSuccessfulTranscription(transcription)
                case .failure(let error):
                    self?.handleTranscriptionError(error)
                }
            }
        }
    }
    
    private func handleSuccessfulTranscription(_ transcription: String) {
        updateOverlayStatus(.done)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hideOverlay()
            ClipboardManager.shared.copyToClipboard(transcription)
            if self.settingsStore.autoInsert && AppDelegateHelpers.checkAccessibilityPermissions() {
                ClipboardManager.shared.insertText(transcription)
            }
        }
    }
    
    private func handleTranscriptionError(_ error: Error) {
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
