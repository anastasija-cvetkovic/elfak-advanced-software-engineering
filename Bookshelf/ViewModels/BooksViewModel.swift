// BooksViewModel.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// The single ViewModel for the entire app. It bridges Core Data, NetworkMonitor,
// and SyncService to SwiftUI views through the @Observable macro (iOS 17+).
//
// WHY @Observable instead of ObservableObject + @Published?
//   @Observable uses the Observation framework to automatically track which properties
//   are read by each view. Only the views that actually read a changed property
//   re-render — more efficient than @Published which always notifies all observers.
//
//   Before (iOS 16):
//     class BooksViewModel: ObservableObject {
//         @Published var books: [Book] = []
//     }
//
//   After (iOS 17):
//     @Observable
//     class BooksViewModel {
//         var books: [Book] = []   // @Observable instruments this automatically
//     }

import CoreData
import Observation
import Foundation

@Observable
final class BooksViewModel {

    // MARK: - Published State

    private(set) var books: [Book] = []
    var errorMessage: String?
    var showSyncLog: Bool = false

    // MARK: - Services (exposed so Views can read network/sync state directly)

    let networkMonitor: NetworkMonitor
    let syncService: SyncService

    // MARK: - Private

    private let persistence: PersistenceController
    private var syncObservationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        persistence: PersistenceController = .shared,
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        syncService: SyncService? = nil
    ) {
        self.persistence    = persistence
        self.networkMonitor = networkMonitor
        self.syncService    = syncService ?? SyncService(persistence: persistence)

        fetchBooks()
        observeNetworkChanges()
    }

    deinit {
        syncObservationTask?.cancel()
    }

    // MARK: - Core Data Read

    /// Fetches all BookEntity records and converts them to Book domain values.
    /// Called after every write operation and on app foreground.
    func fetchBooks() {
        let request = BookEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BookEntity.createdAt, ascending: false)
        ]
        let entities = (try? persistence.viewContext.fetch(request)) ?? []
        books = entities.map { $0.toDomainModel() }
    }

    // MARK: - CRUD

    func addBook(title: String, author: String, rating: Int,
                 notes: String, isRead: Bool) {
        let context = persistence.viewContext
        let entity  = BookEntity(context: context)
        let book    = Book.new(title: title, author: author,
                               rating: rating, notes: notes, isRead: isRead)
        entity.update(from: book)
        persistence.save(context: context)
        fetchBooks()
        syncService.logQueued(bookTitle: title, operation: "CREATE")

        // Attempt immediate sync if we're online
        triggerSyncIfOnline()
    }

    func updateBook(_ book: Book, title: String, author: String, rating: Int,
                    notes: String, isRead: Bool) {
        let context = persistence.viewContext
        let request = BookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", book.id as CVarArg)

        guard let entity = (try? context.fetch(request))?.first else { return }

        entity.title      = title
        entity.author     = author
        entity.rating     = Int16(rating)
        entity.notes      = notes
        entity.isRead     = isRead
        entity.syncStatus = SyncStatus.pending.rawValue  // Mark dirty: needs re-sync
        entity.updatedAt  = Date()
        persistence.save(context: context)
        fetchBooks()
        syncService.logQueued(bookTitle: title, operation: "UPDATE")

        triggerSyncIfOnline()
    }

    func deleteBook(_ book: Book) {
        let context = persistence.viewContext
        let request = BookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", book.id as CVarArg)

        guard let entity = (try? context.fetch(request))?.first else { return }
        context.delete(entity)
        persistence.save(context: context)
        fetchBooks()
        syncService.logDeletion(bookTitle: book.title)
    }

    // MARK: - Sample Books

    func addSampleBooks() {
        Task { @MainActor in
            do {
                let samples = try await syncService.loadSampleBooks()
                let context = persistence.viewContext
                for book in samples {
                    // Avoid duplicates: skip if remoteId already exists
                    let dup = BookEntity.fetchRequest()
                    dup.predicate = NSPredicate(format: "remoteId == %lld",
                                                book.remoteId ?? 0)
                    if (try? context.fetch(dup))?.isEmpty == false { continue }

                    let entity = BookEntity(context: context)
                    entity.update(from: book)
                }
                persistence.save(context: context)
                fetchBooks()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Manual Sync (pull-to-refresh)

    func manualSync() {
        guard networkMonitor.effectivelyOnline else {
            errorMessage = "Cannot sync while offline. Connect to the internet and try again."
            return
        }
        triggerSyncIfOnline()
    }

    // MARK: - Auto-Sync on Connectivity Change

    /// Uses withObservationTracking to react only when effectivelyOnline actually changes.
    /// This fires zero work while the state is stable — no polling overhead.
    private func observeNetworkChanges() {
        var previouslyOnline = networkMonitor.effectivelyOnline

        syncObservationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                // withObservationTracking suspends until effectivelyOnline is mutated
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.networkMonitor.effectivelyOnline
                    } onChange: {
                        continuation.resume()
                    }
                }

                let isOnline = self.networkMonitor.effectivelyOnline
                // Only sync when transitioning offline → online
                if isOnline && !previouslyOnline {
                    await self.syncService.syncPendingBooks()
                    self.fetchBooks()
                }
                previouslyOnline = isOnline
            }
        }
    }

    // MARK: - Private Helpers

    private func triggerSyncIfOnline() {
        guard networkMonitor.effectivelyOnline else { return }
        Task {
            await syncService.syncPendingBooks()
            await MainActor.run { fetchBooks() }
        }
    }
}
