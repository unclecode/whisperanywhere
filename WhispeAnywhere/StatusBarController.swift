import Cocoa

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    
    var onPreferencesClicked: (() -> Void)?
    var onStartStopRecording: (() -> Void)?
    var showLogWindow: (() -> Void)?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        
        setupMenuItems()
        setupStatusBarIcon()
        
        Logger.log("StatusBarController initialized")
    }
    
    private func setupStatusBarIcon() {
        if let button = statusItem.button {
            if let image = NSImage(named: "StatusBarIcon") {
                button.image = image
            } else {
                Logger.log("StatusBarIcon not found, using default image")
                button.title = "🎙️" // Microphone emoji as a fallback
            }
        }
        statusItem.menu = menu
    }
    
    private func setupMenuItems() {
        let startStopItem = NSMenuItem(title: "Start/Stop Recording", action: #selector(startStopRecording), keyEquivalent: "")
        startStopItem.target = self
        
        let viewLogItem = NSMenuItem(title: "View Log", action: #selector(viewLog), keyEquivalent: "l")
        viewLogItem.target = self
        
        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        
        menu.addItem(startStopItem)
        menu.addItem(viewLogItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(preferencesItem)
        menu.addItem(quitItem)
        
        Logger.log("Menu items set up")
    }
    
    @objc private func startStopRecording() {
        Logger.log("Start/Stop Recording menu item clicked")
        onStartStopRecording?()
    }
    
    @objc private func viewLog() {
        Logger.log("View Log menu item clicked")
        showLogWindow?()
    }
    
    @objc private func openPreferences() {
        Logger.log("Preferences menu item clicked")
        onPreferencesClicked?()
    }
    
    func updateRecordingStatus(isRecording: Bool) {
        if let startStopItem = menu.item(at: 0) {
            startStopItem.title = isRecording ? "Stop Recording" : "Start Recording"
        }
    }
}
