// SyncService.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// THE HEART OF OFFLINE-FIRST ARCHITECTURE.
//
// Responsibilities:
//   1. Query Core Data for all books with syncStatus = "pending" or "failed"
//   2. For each book, attempt a POST (new) or PUT (updated) to JSONPlaceholder
//   3. On success: update syncStatus = "synced" and store remoteId
//   4. On failure: update syncStatus = "failed" (will be retried on next sync)
//   5. Append every operation to syncLog (shown in SyncLogView)
//
// This service is called:
//   - Automatically when NetworkMonitor.effectivelyOnline changes to true
//   - Immediately after addBook/updateBook if the network is available
//   - Manually via pull-to-refresh

import CoreData
import Observation
import Foundation

@Observable
final class SyncService {

    // MARK: - Observable State

    /// True while a sync pass is running. Used to show a spinner in the UI.
    private(set) var isSyncing: Bool = false

    /// Chronological log of all sync operations. Newest entries at index 0.
    /// Capped at 50 entries to avoid unbounded memory growth.
    private(set) var syncLog: [SyncLogEntry] = []

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let api: APIService

    init(persistence: PersistenceController = .shared,
         api: APIService = APIService()) {
        self.persistence = persistence
        self.api = api
    }

    // MARK: - Main Sync Entry Point

    /// Processes every pending/failed book in the local queue.
    /// Safe to call concurrently — guard prevents overlapping runs.
    func syncPendingBooks() async {
        let alreadySyncing = await MainActor.run { isSyncing }
        guard !alreadySyncing else { return }
        await MainActor.run { isSyncing = true }
        defer {
            Task { @MainActor [weak self] in
                self?.isSyncing = false
            }
        }

        let context = persistence.backgroundContext
        let pending = await fetchPendingEntities(context: context)

        if pending.isEmpty { return }

        appendLog(bookTitle: "—", operation: "SYNC START",
                  outcome: "QUEUED", detail: "\(pending.count) item(s) in queue")

        for entity in pending {
            await syncSingleBook(entity, context: context)
        }
    }

    // MARK: - Per-Book Sync

    private func syncSingleBook(_ entity: BookEntity,
                                 context: NSManagedObjectContext) async {
        let title = await context.perform { entity.title ?? "Unknown" }
        let currentRemoteId = await context.perform { entity.remoteId }

        do {
            if currentRemoteId == 0 {
                // New book — CREATE on server
                let remote = try await api.createPost(
                    title: title,
                    body: await context.perform { entity.notes ?? "" }
                )
                await context.perform {
                    entity.remoteId   = Int64(remote.id)
                    entity.syncStatus = SyncStatus.synced.rawValue
                    self.persistence.save(context: context)
                }
                appendLog(bookTitle: title, operation: "CREATE",
                          outcome: "SUCCESS", detail: "remoteId = \(remote.id)")

            } else {
                // Existing book — UPDATE on server
                let remote = try await api.updatePost(
                    id: Int(currentRemoteId),
                    title: title,
                    body: await context.perform { entity.notes ?? "" }
                )
                await context.perform {
                    entity.syncStatus = SyncStatus.synced.rawValue
                    self.persistence.save(context: context)
                }
                appendLog(bookTitle: title, operation: "UPDATE",
                          outcome: "SUCCESS", detail: "remoteId = \(remote.id)")
            }

        } catch {
            await context.perform {
                entity.syncStatus = SyncStatus.failed.rawValue
                self.persistence.save(context: context)
            }
            appendLog(bookTitle: title, operation: "SYNC",
                      outcome: "FAILED", detail: error.localizedDescription)
        }
    }

    // MARK: - Fetch Pending/Failed Entities

    private func fetchPendingEntities(context: NSManagedObjectContext) async -> [BookEntity] {
        await context.perform {
            let request = BookEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "syncStatus == %@ OR syncStatus == %@",
                SyncStatus.pending.rawValue,
                SyncStatus.failed.rawValue
            )
            return (try? context.fetch(request)) ?? []
        }
    }

    // MARK: - Sample Books from JSONPlaceholder

    /// Fetches 5 posts from JSONPlaceholder and converts them to Book values.
    /// These are already "synced" because they came FROM the server.
    func loadSampleBooks() async throws -> [Book] {
        let posts = try await api.fetchPosts(limit: 5)
        return posts.map { post in
            Book(
                id:         UUID(),
                title:      String(post.title.prefix(60)).capitalized,
                author:     "Author #\(post.userId)",
                rating:     Int.random(in: 3...5),
                notes:      String(post.body.prefix(120)),
                isRead:     Bool.random(),
                syncStatus: .synced,
                remoteId:   Int64(post.id),
                createdAt:  Date(),
                updatedAt:  Date()
            )
        }
    }

    // MARK: - Sync Log

    private func appendLog(bookTitle: String, operation: String,
                           outcome: String, detail: String) {
        let entry = SyncLogEntry(
            timestamp:  Date(),
            bookTitle:  bookTitle,
            operation:  operation,
            outcome:    outcome,
            detail:     detail
        )
        DispatchQueue.main.async {
            self.syncLog.insert(entry, at: 0)
            if self.syncLog.count > 50 {
                self.syncLog = Array(self.syncLog.prefix(50))
            }
        }
    }
}
