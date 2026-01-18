import SwiftUI
import CoreData

@MainActor

class iClip: NSObject, NSApplicationDelegate {
    
    final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }
    
    var overlayWindow: [NSWindow] = []
    var wasHotKeyPressed = false
    
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    
    func createOverlay() {
        
        overlayWindow.forEach{ $0.close() }
        overlayWindow.removeAll()
        
        let windowSize = NSSize(width: 320, height: 100)
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let window = OverlayWindow(
            contentRect: NSRect(
                origin: CGPoint(
                    x: screenFrame.midX - windowSize.width / 2,
                    y: screenFrame.midY - windowSize.height / 2
                ),
                size: windowSize
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        window.contentView = NSHostingView(
            rootView: ClipWindow()
        )
        
        overlayWindow.append(window)
    }
    
    func toggleOverlay() {
        if self.overlayWindow.contains(where: {$0.isVisible}) {
            self.overlayWindow.forEach{ $0.orderOut(nil) }
            return
        }
        
        self.createOverlay()
        self.overlayWindow.forEach{ $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setUpHotKey() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task{ @MainActor in self?.handleFlagsChanged(event)}
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isHotKeyPressed = flags.contains(.control) && flags.contains(.option)
        
        if isHotKeyPressed && !wasHotKeyPressed {
            toggleOverlay()
        }
        
        wasHotKeyPressed = isHotKeyPressed
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let global = globalEventMonitor {
            NSEvent.removeMonitor(global)
            globalEventMonitor = nil
        }

        if let local = localEventMonitor {
            NSEvent.removeMonitor(local)
            localEventMonitor = nil
        }
    }
    
    struct ClipWindow: View {
        
        @State private var query = ""
        @FocusState private var isFocused: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                TextField("Search in clipboard history...", text: $query)
                    .focused($isFocused)
            }
            .frame(width: 320, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .cornerRadius(16)
            )
            .padding()
            .onAppear{
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
    }
}
