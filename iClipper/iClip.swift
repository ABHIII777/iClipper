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
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                guard let self else { return }
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
    
    var overlayWindow: NSWindow?
    var wasHotKeyPressed = false
    
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var navigationMonitor: Any?
    
    var selectedIndex: Int = 0
    
    let clipboardStore = ClipboardStore()
    
    func createOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        
        let windowSize = NSSize(width: 360, height: 420)
        
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
            rootView: CombinedSearchView(
                store: clipboardStore
            )
        )
        
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window
    }
    
    func toggleOverlay() {
        if self.overlayWindow?.isVisible == true {
            overlayWindow?.orderOut(nil)
            stopNavigation()
            return
        }
        
        createOverlay()
        NSApp.activate(ignoringOtherApps: true)
        
        startNavigation()
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
    
    func startNavigation() {
        stopNavigation()
        
        navigationMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            
            switch event.keyCode {
            case 125:
                self.moveSelection(+1)
                return nil
                
            case 126:
                self.moveSelection(-1)
                return nil
                
            default:
                return event
            }
        }
    }
    
    func stopNavigation() {
        if let monitor = navigationMonitor{
            NSEvent.removeMonitor(monitor)
            navigationMonitor = nil
        }
    }
    
    func moveSelection(_ delta: Int) {
        let count = clipboardStore.history.count
        guard count > 0 else { return }
        
        selectedIndex = (selectedIndex + delta + count) % count
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
    
    
//    UI
    struct SearchWindow: View {
        
        @Binding var query: String
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
                RoundedRectangle(cornerRadius: 0)
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
        
        let items: [String]
        
        var body: some View {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(.ultraThinMaterial)
                                    .border(Color.accentColor, width: 0.5)
                                    .cornerRadius(8)
                            )
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    struct CombinedSearchView: View {
        @State private var query = ""
        @FocusState private var isFocused: Bool
        @ObservedObject var store: ClipboardStore
        
        var filteredData: [String] {
            query.isEmpty
            ? store.history
            : store.history.filter { $0.localizedCaseInsensitiveContains(query) }
        }

        var body: some View {
            VStack(spacing: 12) {
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search in clipboard history…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .focused($isFocused)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )
                .onAppear {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }

                
                VStack(spacing: 0) {
                    ForEach(filteredData, id: \.self) { item in
                        HStack {
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            Color.white.opacity(0.03)
                                .opacity(0.0001)
                        )

                        Divider()
                            .opacity(0.15)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(14)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1))
            )
        }
    }

}
