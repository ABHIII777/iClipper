import SwiftUI
import CoreData

@main
struct iClipperApp: App {
    let persistenceController = PersistenceController.shared
    
    @NSApplicationDelegateAdaptor(iClip.self)
    var appDelegate: iClip
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
