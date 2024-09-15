import Cocoa
import Carbon

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
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID: EventHotKeyID
    private weak var delegate: HotkeyManagerDelegate?
    
    @Published var currentHotkey: String {
        didSet {
            print("Hotkey changed to: \(currentHotkey)")
            updateHotkey()
        }
    }
    
    private static weak var sharedInstance: HotkeyManager?
    
    init(settingsStore: SettingsStore, delegate: HotkeyManagerDelegate) {
        self.delegate = delegate
        self.currentHotkey = settingsStore.hotkey
        self.hotKeyID = EventHotKeyID(signature: OSType("swat".fourCharCodeValue), id: 1)
        
        print("Initializing HotkeyManager with hotkey: \(settingsStore.hotkey)")
        
        HotkeyManager.sharedInstance = self
        
        // Observe changes in SettingsStore
        settingsStore.$hotkey.assign(to: &$currentHotkey)
        
        updateHotkey()
    }
    
    private func updateHotkey() {
        print("Updating hotkey...")
        unregisterHotkey()
        registerHotkey()
    }
    
    private func registerHotkey() {
        let (keyCode, modifiers) = parseHotkeyString(currentHotkey)
        let modifierFlags = getCarbonFlagsFromCocoaFlags(cocoaFlags: modifiers)
        
        print("Registering hotkey with keyCode: \(keyCode), modifiers: \(modifiers)")
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // Use a static function as the event handler
        let status = InstallEventHandler(GetApplicationEventTarget(), Self.eventHandler, 1, &eventType, nil, nil)
        if status != noErr {
            print("Failed to install event handler. Status: \(status)")
            return
        }
        
        let registerStatus = RegisterEventHotKey(UInt32(keyCode),
                                                 modifierFlags,
                                                 hotKeyID,
                                                 GetApplicationEventTarget(),
                                                 0,
                                                 &hotKeyRef)
        
        if registerStatus == noErr {
            print("Hotkey registered successfully")
        } else {
            print("Failed to register hotkey. Status: \(registerStatus)")
        }
    }
    
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            print("Unregistering previous hotkey")
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    private static let eventHandler: EventHandlerUPP = { (nextHandler, eventRef, userData) -> OSStatus in
        guard let eventRef = eventRef else { return noErr }
        print("Hotkey event received")
        DispatchQueue.main.async {
            HotkeyManager.sharedInstance?.delegate?.hotkeyTriggered()
        }
        return noErr
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
        default: return 0
        }
    }
    
    private func getCarbonFlagsFromCocoaFlags(cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if cocoaFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if cocoaFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if cocoaFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if cocoaFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyTriggered()
}
