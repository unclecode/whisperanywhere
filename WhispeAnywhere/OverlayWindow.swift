import Cocoa
import SwiftUI
import QuartzCore

class StatusManager: ObservableObject {
    @Published var status: RecordingStatus = .recording
}

import Cocoa
import QuartzCore

class OverlayWindow: NSPanel {
    private var hostingView: NSHostingView<OverlayContentView>?
    private var trackingArea: NSTrackingArea?
    
    private var statusManager = StatusManager()
    
    init() {
        super.init(contentRect: NSRect(x: 100, y: 100, width: 60, height: 60),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        
        self.level = .floating
        self.isFloatingPanel = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        
        let contentView = OverlayContentView(statusManager: statusManager)
        self.hostingView = NSHostingView(rootView: contentView)
        self.contentView = self.hostingView
        
        setupTrackingArea()
    }
    
    func updateStatus(_ newStatus: RecordingStatus) {
        statusManager.status = newStatus
    }
    
    private func setupTrackingArea() {
        guard let contentView = self.contentView else { return }
        
        if let trackingArea = trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: contentView.bounds, options: options, owner: self, userInfo: nil)
        contentView.addTrackingArea(trackingArea!)
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Update the overlay position directly
        updatePosition(with: event.locationInWindow)
    }
    
    func updatePosition(with point: NSPoint) {
        guard let screenFrame = NSScreen.main?.frame else { return }
        
        let windowSize = self.frame.size
        let newOrigin = NSPoint(
            x: min(max(point.x + 10, 0), screenFrame.width - windowSize.width),
            y: min(max(point.y + 10, 0), screenFrame.height - windowSize.height)
        )
        
        // Directly update the frame without animation for smoother movement
        self.setFrameOrigin(newOrigin)
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        setupTrackingArea()
    }
}


struct OverlayContentView: View {
    @ObservedObject var statusManager: StatusManager
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(statusManager.status.backgroundColor)
                .frame(width: 50, height: 50)

            Text(statusManager.status.emoji)
                .font(.system(size: 30))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .frame(width: 60, height: 60)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}



enum RecordingStatus: Int {
    case recording = 0
    case processing = 1
    case done = 2
    case error = 3
    
    var emoji: String {
        switch self {
        case .recording: return "🎙️"
        case .processing: return "⏳"
        case .done: return "✅"
        case .error: return "❌"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .recording: return .red.opacity(0.7)
        case .processing: return .orange.opacity(0.7)
        case .done: return .green.opacity(0.7)
        case .error: return .red.opacity(0.7)
        }
    }
}
