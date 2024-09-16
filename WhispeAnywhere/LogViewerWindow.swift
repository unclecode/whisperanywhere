import Cocoa

class LogViewerWindow: NSWindow {
    private var textView: NSTextView!
    
    init() {
        super.init(contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered,
                   defer: false)
        
        self.title = "Application Log"
        self.minSize = NSSize(width: 400, height: 300)
        
        setupTextView()
        setupToolbar()
        
        Logger.log("Log viewer window initialized")
    }
    
    private func setupTextView() {
        textView = NSTextView(frame: self.contentView!.bounds)
        textView.isEditable = false
        textView.autoresizingMask = [.width, .height]
        
        let scrollView = NSScrollView(frame: self.contentView!.bounds)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        self.contentView?.addSubview(scrollView)
    }
    
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "LogViewerToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        self.toolbar = toolbar
    }
    
    func updateLogContent() {
        if let logContent = Logger.viewLogFile() {
            textView.string = logContent
            textView.scrollToEndOfDocument(nil)
        } else {
            textView.string = "Unable to load log content."
        }
    }
    
    @objc func clearLog() {
        Logger.clearLog()
        updateLogContent()
        Logger.log("Log cleared")
    }
}

extension LogViewerWindow: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .clearLog:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Clear Log"
            item.paletteLabel = "Clear Log"
            item.toolTip = "Clear the log content"
            item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear")
            item.target = self
            item.action = #selector(clearLog)
            return item
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .clearLog]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .clearLog]
    }
}

extension NSToolbarItem.Identifier {
    static let clearLog = NSToolbarItem.Identifier("ClearLog")
}
