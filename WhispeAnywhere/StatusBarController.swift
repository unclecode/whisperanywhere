import Cocoa
import SwiftUI

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    
    var onPreferencesClicked: (() -> Void)?
    var onStartStopRecording: (() -> Void)?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        
        setupMenuItems()
        
        if let button = statusItem.button {
            if let image = NSImage(named: "StatusBarIcon") {
                button.image = image
            } else {
                print("StatusBarIcon not found, using default image")
                button.title = "🎙️" // Microphone emoji as a fallback
            }
        }
        statusItem.menu = menu
    }
    
    private func setupMenuItems() {
        let startStopItem = NSMenuItem(title: "Start/Stop Recording", action: #selector(startStopRecording), keyEquivalent: "")
        startStopItem.target = self
        
        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        
        menu.addItem(startStopItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(preferencesItem)
        menu.addItem(quitItem)
    }
    
    @objc private func startStopRecording() {
        onStartStopRecording?()
    }
    
    @objc private func openPreferences() {
        onPreferencesClicked?()
    }
}
