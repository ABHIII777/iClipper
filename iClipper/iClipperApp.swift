//
//  iClipperApp.swift
//  iClipper
//
//  Created by Abhi Patel on 18/01/26.
//

import SwiftUI
import CoreData

@main
struct iClipperApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
