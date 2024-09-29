import Cocoa
import Carbon
import Combine

extension String {
    var fourCharCodeValue: Int {
        var result: Int = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { (rawBytes) in
                let bytes = rawBytes.bindMemory(to: UInt8.self)
                for i in 0 ..< data.count {
                    result = result << 8 + Int(bytes[i])
                }
            }
        }
        return result
    }
}

class HotkeyManager: ObservableObject {
    private var hotKeyRefs: [String: EventHotKeyRef] = [:]
    private var hotKeyIDs: [String: EventHotKeyID] = [:]
    private weak var delegate: HotkeyManagerDelegate?
    private var settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var eventHandlerInstalled = false
    
    @Published var hotkeys: [String: String] {
        didSet {
            print("Hotkeys changed: \(hotkeys)")
            updateHotkeys()
        }
    }
    
    private static weak var sharedInstance: HotkeyManager?
    
    init(settingsStore: SettingsStore, delegate: HotkeyManagerDelegate) {
        self.settingsStore = settingsStore
        self.delegate = delegate
        self.hotkeys = [
            "toggleRecording": settingsStore.recordingHotkey,
            "showSpotlightChat": settingsStore.spotlightChatHotkey,
            "escape": "Escape"
        ]
        
        HotkeyManager.sharedInstance = self
        
        // Install event handler once during initialization
        installEventHandler()
        
        // Observe changes in SettingsStore
        settingsStore.$recordingHotkey
            .sink { [weak self] newValue in
                self?.hotkeys["toggleRecording"] = newValue
            }
            .store(in: &cancellables)
        
        settingsStore.$spotlightChatHotkey
            .sink { [weak self] newValue in
                self?.hotkeys["showSpotlightChat"] = newValue
            }
            .store(in: &cancellables)
        
        updateHotkeys()
    }
    
    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), Self.eventHandler, 1, &eventType, nil, nil)
        if status == noErr {
            eventHandlerInstalled = true
            print("Event handler installed successfully")
        } else {
            print("Failed to install event handler. Status: \(status)")
        }
    }
    
    private func updateHotkeys() {
        print("Updating hotkeys...")
        unregisterAllHotkeys()
        registerAllHotkeys()
    }
    
    private func registerAllHotkeys() {
        for (action, hotkeyString) in hotkeys {
            registerHotkey(for: action, hotkeyString: hotkeyString)
        }
    }
    
    private func registerHotkey(for action: String, hotkeyString: String) {
        let (keyCode, modifiers) = parseHotkeyString(hotkeyString)
        let modifierFlags = getCarbonFlagsFromCocoaFlags(cocoaFlags: modifiers)
        
        print("Registering hotkey for \(action) with keyCode: \(keyCode), modifiers: \(modifiers)")
        
        // Create a unique identifier for this hotkey
        let signatureHash = abs(action.hashValue) & 0xFFFFFFFF
        let hotKeyID = EventHotKeyID(signature: OSType(signatureHash), id: UInt32(hotKeyIDs.count + 1))
        hotKeyIDs[action] = hotKeyID
        
        var hotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(UInt32(keyCode),
                                                 modifierFlags,
                                                 hotKeyID,
                                                 GetApplicationEventTarget(),
                                                 0,
                                                 &hotKeyRef)
        
        if registerStatus == noErr, let hotKeyRef = hotKeyRef {
            hotKeyRefs[action] = hotKeyRef
            print("Hotkey for \(action) registered successfully")
        } else {
            print("Failed to register hotkey for \(action). Status: \(registerStatus)")
        }
    }
    
    private func unregisterAllHotkeys() {
        for (action, hotKeyRef) in hotKeyRefs {
            print("Unregistering hotkey for \(action)")
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        hotKeyIDs.removeAll()
    }
    
    private static let eventHandler: EventHandlerUPP = { (nextHandler, eventRef, userData) -> OSStatus in
        guard let eventRef = eventRef else { return noErr }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        
        if status == noErr {
            DispatchQueue.main.async {
                if let action = HotkeyManager.sharedInstance?.hotKeyIDs.first(where: { $0.value.id == hotKeyID.id })?.key {
                    HotkeyManager.sharedInstance?.delegate?.hotkeyTriggered(for: action)
                }
            }
        }
        
        return noErr
    }
    
    private func getCarbonFlagsFromCocoaFlags(cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if cocoaFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if cocoaFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if cocoaFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if cocoaFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }
    
    deinit {
            unregisterAllHotkeys()
            cancellables.forEach { $0.cancel() }
        }
    
    private func parseHotkeyString(_ hotkeyString: String) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            let components = hotkeyString.components(separatedBy: "+")
            var modifiers: NSEvent.ModifierFlags = []
            var keyCode: UInt16 = 0
            
            for component in components {
                switch component.lowercased() {
                case "cmd", "command":
                    modifiers.insert(.command)
                case "ctrl", "control":
                    modifiers.insert(.control)
                case "alt", "option":
                    modifiers.insert(.option)
                case "shift":
                    modifiers.insert(.shift)
                default:
                    keyCode = keyCodeForChar(component)
                }
            }
            
            return (keyCode, modifiers)
        }
    
    private func keyCodeForChar(_ char: String) -> UInt16 {
        switch char.uppercased() {
        case "A": return UInt16(kVK_ANSI_A)
        case "S": return UInt16(kVK_ANSI_S)
        case "D": return UInt16(kVK_ANSI_D)
        case "F": return UInt16(kVK_ANSI_F)
        case "H": return UInt16(kVK_ANSI_H)
        case "G": return UInt16(kVK_ANSI_G)
        case "Z": return UInt16(kVK_ANSI_Z)
        case "X": return UInt16(kVK_ANSI_X)
        case "C": return UInt16(kVK_ANSI_C)
        case "V": return UInt16(kVK_ANSI_V)
        case "B": return UInt16(kVK_ANSI_B)
        case "Q": return UInt16(kVK_ANSI_Q)
        case "W": return UInt16(kVK_ANSI_W)
        case "E": return UInt16(kVK_ANSI_E)
        case "R": return UInt16(kVK_ANSI_R)
        case "Y": return UInt16(kVK_ANSI_Y)
        case "T": return UInt16(kVK_ANSI_T)
        case "1": return UInt16(kVK_ANSI_1)
        case "2": return UInt16(kVK_ANSI_2)
        case "3": return UInt16(kVK_ANSI_3)
        case "4": return UInt16(kVK_ANSI_4)
        case "6": return UInt16(kVK_ANSI_6)
        case "5": return UInt16(kVK_ANSI_5)
        case "=": return UInt16(kVK_ANSI_Equal)
        case "9": return UInt16(kVK_ANSI_9)
        case "7": return UInt16(kVK_ANSI_7)
        case "-": return UInt16(kVK_ANSI_Minus)
        case "8": return UInt16(kVK_ANSI_8)
        case "0": return UInt16(kVK_ANSI_0)
        case "]": return UInt16(kVK_ANSI_RightBracket)
        case "O": return UInt16(kVK_ANSI_O)
        case "U": return UInt16(kVK_ANSI_U)
        case "[": return UInt16(kVK_ANSI_LeftBracket)
        case "I": return UInt16(kVK_ANSI_I)
        case "P": return UInt16(kVK_ANSI_P)
        case "L": return UInt16(kVK_ANSI_L)
        case "J": return UInt16(kVK_ANSI_J)
        case "'": return UInt16(kVK_ANSI_Quote)
        case "K": return UInt16(kVK_ANSI_K)
        case ";": return UInt16(kVK_ANSI_Semicolon)
        case "\\": return UInt16(kVK_ANSI_Backslash)
        case ",": return UInt16(kVK_ANSI_Comma)
        case "/": return UInt16(kVK_ANSI_Slash)
        case "N": return UInt16(kVK_ANSI_N)
        case "M": return UInt16(kVK_ANSI_M)
        case ".": return UInt16(kVK_ANSI_Period)
        case "`": return UInt16(kVK_ANSI_Grave)
        case "Space": return UInt16(kVK_Space)
        case "ESCAPE": return UInt16(kVK_Escape)
        default: return 0
        }
    }
    
    
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyTriggered(for action: String)
}
