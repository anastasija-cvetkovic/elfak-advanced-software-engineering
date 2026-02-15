// BookshelfApp.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// App entry point. Initialises the Core Data stack once and injects
// the managed object context into the SwiftUI environment.

import SwiftUI

@main
struct BookshelfApp: App {

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                              persistenceController.viewContext)
        }
    }
}
