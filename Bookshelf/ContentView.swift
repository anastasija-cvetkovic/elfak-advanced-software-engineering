// ContentView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial

import SwiftUI

struct ContentView: View {
    var body: some View {
        BookListView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                      PersistenceController.preview.viewContext)
}
