import SwiftUI
import CoreData
import AppKit
import Combine

@MainActor

class iClip: NSObject, NSApplicationDelegate {
    
    final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }
    
    final class ClipboardStore: ObservableObject {
        @Published var history: [String] = []
        
        private var lastChange = NSPasteboard.general.changeCount
        private var timer: Timer?
        
        init() {
            start()
        }
        
        func start() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                let pb = NSPasteboard.general
                
                if pb.changeCount != self.lastChange {
                    self.lastChange = pb.changeCount
                    
                    if let str = pb.string(forType: .string) {
                        DispatchQueue.main.async {
                            if self.history.first != str {
                                self.history.insert(str, at: 0)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var overlayWindow: [NSWindow] = []
    var wasHotKeyPressed = false
    
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    
    let clipboardStore = ClipboardStore()
    
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
            rootView: VStack {
                SearchWindow()
                    .padding()
                SearchResult(ClipboardData: clipboardStore)
            }
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
    
    func CData() -> String? {
        let pasteBoard = NSPasteboard.general
        return pasteBoard.string(forType: .string)
    }
    
    
//    UI
    struct SearchWindow: View {
        
        @State private var query = ""
        @FocusState private var isFocused: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                TextField("Search in clipboard history...", text: $query)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .padding(.leading, 14)
            }
            .frame(width: 320, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .border(Color.accentColor, width: 0.5)
                    .cornerRadius(8)
            )
            .onAppear {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
    }
    
    struct SearchResult: View {
        
        @ObservedObject var ClipboardData: ClipboardStore
        
        var body: some View {
            VStack (spacing: 8) {
                ForEach(ClipboardData.history.prefix(5), id: \.self) { item in
                    Text(item)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
            
            .frame(width: 320)
        }
    }
}
