// SyncServiceTests.swift
// Trusty Bookshelf — BookshelfTests
//
// Unit tests for SyncService — the heart of the offline-first architecture.
//
// Uses a MockAPIService subclass to control success/failure without real network calls.
//
// NOTE: In production code you would define an APIServiceProtocol and inject it.
// For this tutorial, subclassing is used to keep the code short and readable —
// which is the right trade-off for an educational project.

import XCTest
import CoreData
@testable import Bookshelf

// MARK: - Mock API Service

final class MockAPIService: APIService {

    var shouldFail = false
    var createCallCount = 0
    var updateCallCount = 0

    override func createPost(title: String,
                             body: String,
                             userId: Int = 1) async throws -> RemotePost {
        createCallCount += 1
        if shouldFail {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        return RemotePost(id: 101, title: title, body: body, userId: userId)
    }

    override func updatePost(id: Int,
                             title: String,
                             body: String) async throws -> RemotePost {
        updateCallCount += 1
        if shouldFail {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        return RemotePost(id: id, title: title, body: body, userId: 1)
    }
}

// MARK: - Helper

private func makeEntity(in ctx: NSManagedObjectContext,
                        title: String,
                        syncStatus: SyncStatus = .pending,
                        remoteId: Int64 = 0) -> BookEntity {
    let entity = BookEntity(context: ctx)
    entity.id         = UUID()
    entity.title      = title
    entity.author     = "Test Author"
    entity.rating     = 3
    entity.notes      = ""
    entity.isRead     = false
    entity.syncStatus = syncStatus.rawValue
    entity.remoteId   = remoteId
    entity.createdAt  = Date()
    entity.updatedAt  = Date()
    return entity
}

// MARK: - Tests

final class SyncServiceTests: XCTestCase {

    var persistence: PersistenceController!
    var mockAPI: MockAPIService!
    var syncService: SyncService!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        mockAPI     = MockAPIService()
        syncService = SyncService(persistence: persistence, api: mockAPI)
    }

    override func tearDown() {
        syncService = nil
        mockAPI     = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    /// All pending books should become .synced after a successful sync.
    func test_syncPendingBooks_syncsAllPending() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Book A")
        _ = makeEntity(in: ctx, title: "Book B")
        try ctx.save()

        await syncService.syncPendingBooks()

        let entities = try ctx.fetch(BookEntity.fetchRequest())
        XCTAssertEqual(entities.count, 2)
        XCTAssertTrue(entities.allSatisfy { $0.syncStatus == SyncStatus.synced.rawValue },
                      "All pending books must become .synced on a successful sync")
        XCTAssertEqual(mockAPI.createCallCount, 2)
    }

    /// New books (remoteId == 0) must use CREATE (POST).
    func test_newBook_usesCreate() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "New Book", remoteId: 0)
        try ctx.save()

        await syncService.syncPendingBooks()

        XCTAssertEqual(mockAPI.createCallCount, 1)
        XCTAssertEqual(mockAPI.updateCallCount, 0)
    }

    /// Books with an existing remoteId must use UPDATE (PUT).
    func test_existingBook_usesUpdate() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Edited Book",
                       syncStatus: .pending, remoteId: 42)
        try ctx.save()

        await syncService.syncPendingBooks()

        XCTAssertEqual(mockAPI.updateCallCount, 1)
        XCTAssertEqual(mockAPI.createCallCount, 0)
    }

    // MARK: - Failure Handling

    /// A network error during sync must mark the book as .failed, not crash.
    func test_syncPendingBooks_onNetworkError_marksFailed() async throws {
        mockAPI.shouldFail = true

        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Fail Book")
        try ctx.save()

        await syncService.syncPendingBooks()

        let entity = try XCTUnwrap(try ctx.fetch(BookEntity.fetchRequest()).first)
        XCTAssertEqual(entity.syncStatus, SyncStatus.failed.rawValue,
                       "A network failure must set syncStatus to .failed")
    }

    // MARK: - Retry Behaviour

    /// Books in .failed state must be included in the next sync attempt.
    func test_failedBooks_areRetried() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Retry Me", syncStatus: .failed)
        try ctx.save()

        // First attempt: API succeeds (shouldFail is false by default)
        await syncService.syncPendingBooks()

        let entity = try XCTUnwrap(try ctx.fetch(BookEntity.fetchRequest()).first)
        XCTAssertEqual(entity.syncStatus, SyncStatus.synced.rawValue,
                       "Failed books must be retried and become .synced on success")
    }

    // MARK: - No Unnecessary API Calls

    /// Books already in .synced state must not trigger any API calls.
    func test_syncedBooks_areNotResynced() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Already Synced",
                       syncStatus: .synced, remoteId: 99)
        try ctx.save()

        await syncService.syncPendingBooks()

        XCTAssertEqual(mockAPI.createCallCount, 0,
                       "Synced books must never trigger API calls")
        XCTAssertEqual(mockAPI.updateCallCount, 0)
    }

    // MARK: - Concurrent Call Guard

    /// Calling syncPendingBooks twice concurrently must not result in duplicate API calls.
    func test_concurrentSyncCalls_doNotDuplicate() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Once Only")
        try ctx.save()

        // Fire two sync calls simultaneously
        async let first  = syncService.syncPendingBooks()
        async let second = syncService.syncPendingBooks()
        _ = await (first, second)

        // Only one should have run (the second hits the isSyncing guard)
        XCTAssertLessThanOrEqual(mockAPI.createCallCount, 1,
                                  "Concurrent sync calls must not duplicate API requests")
    }

    // MARK: - Sync Log

    /// A successful sync must append an entry to syncLog.
    func test_successfulSync_populatesSyncLog() async throws {
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Log Test")
        try ctx.save()

        await syncService.syncPendingBooks()

        // syncLog is updated on DispatchQueue.main.async — wait a tick
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(syncService.syncLog.isEmpty)
        let entry = syncService.syncLog.first { $0.bookTitle == "Log Test" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.outcome, "SUCCESS")
    }

    /// A failed sync must also append a log entry (with "FAILED" outcome).
    func test_failedSync_populatesLogWithFailure() async throws {
        mockAPI.shouldFail = true
        let ctx = persistence.viewContext
        _ = makeEntity(in: ctx, title: "Failed Log Test")
        try ctx.save()

        await syncService.syncPendingBooks()

        try await Task.sleep(nanoseconds: 100_000_000)

        let entry = syncService.syncLog.first { $0.bookTitle == "Failed Log Test" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.outcome, "FAILED")
    }
}
