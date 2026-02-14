// PersistenceController.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// Encapsulates the entire Core Data stack.
//
// KEY CONCEPT — Two contexts:
//   viewContext      Main thread. Used by SwiftUI views for reading data.
//   backgroundContext Background thread. Used by SyncService for write operations
//                    during sync, so the UI is never blocked.
//
// Changes saved on backgroundContext automatically propagate to viewContext
// because automaticallyMergesChangesFromParent = true.

import CoreData

final class PersistenceController {

    // MARK: - Singleton

    /// Shared instance used by the production app.
    static let shared = PersistenceController()

    // MARK: - Preview Instance

    /// In-memory store used by Xcode Previews and unit tests.
    /// No data is written to disk — tests are isolated and fast.
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.viewContext

        // Seed preview data representing all three sync states
        let books: [(String, String, SyncStatus, Int64)] = [
            ("Clean Code",                     "Robert C. Martin",  .synced,  1),
            ("The Pragmatic Programmer",        "Hunt & Thomas",     .pending, 0),
            ("Designing Data-Intensive Apps",   "Martin Kleppmann",  .failed,  0)
        ]

        for (title, author, status, remoteId) in books {
            let entity = BookEntity(context: ctx)
            entity.id         = UUID()
            entity.title      = title
            entity.author     = author
            entity.rating     = 4
            entity.isRead     = status == .synced
            entity.syncStatus = status.rawValue
            entity.remoteId   = remoteId
            entity.createdAt  = Date()
            entity.updatedAt  = Date()
        }

        try? ctx.save()
        return controller
    }()

    // MARK: - Core Data Stack

    let container: NSPersistentContainer

    /// Main-thread managed object context. Use for UI reads only.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for SyncService writes.
    /// mergePolicy: last-write wins (simplest strategy; appropriate for this tutorial).
    lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Bookshelf")

        if inMemory {
            // /dev/null = no-op persistent store (data lives only in memory)
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                // In production: handle this gracefully (show an error screen).
                // For this tutorial we crash early so the problem is obvious during dev.
                fatalError("Core Data failed to load: \(error)")
            }
        }

        // Automatically merge background saves into the main-thread viewContext.
        // This is what makes the UI update when SyncService finishes a write.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Helper

    /// Saves the given context only if it has pending changes.
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[PersistenceController] Save failed: \(error)")
        }
    }
}
