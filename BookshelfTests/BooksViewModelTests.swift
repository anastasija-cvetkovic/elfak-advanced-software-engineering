// BooksViewModelTests.swift
// Trusty Bookshelf — BookshelfTests
//
// Unit tests for BooksViewModel.
//
// All tests use PersistenceController(inMemory: true) — no data is written to disk,
// and each test starts with an empty store. This makes tests fast and deterministic.
//
// Note: @MainActor is required because BooksViewModel must be created on the main thread
// (Core Data viewContext is main-thread only).

import XCTest
import CoreData
@testable import Bookshelf

@MainActor
final class BooksViewModelTests: XCTestCase {

    var persistence: PersistenceController!
    var monitor: NetworkMonitor!
    var syncService: SyncService!
    var viewModel: BooksViewModel!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        monitor     = NetworkMonitor()
        monitor.simulateOffline = true  // Start offline — prevents real network calls
        syncService = SyncService(persistence: persistence)
        viewModel   = BooksViewModel(
            persistence:    persistence,
            networkMonitor: monitor,
            syncService:    syncService
        )
    }

    override func tearDown() {
        viewModel    = nil
        syncService  = nil
        monitor      = nil
        persistence  = nil
        super.tearDown()
    }

    // MARK: - Add Book Tests

    /// Adding a book creates exactly one record in Core Data and in viewModel.books.
    func test_addBook_createsRecord() {
        XCTAssertEqual(viewModel.books.count, 0)

        viewModel.addBook(title: "Clean Code", author: "Robert C. Martin",
                          rating: 5, notes: "Great book", isRead: true)

        XCTAssertEqual(viewModel.books.count, 1)
        let book = viewModel.books[0]
        XCTAssertEqual(book.title,  "Clean Code")
        XCTAssertEqual(book.author, "Robert C. Martin")
        XCTAssertEqual(book.rating, 5)
        XCTAssertTrue(book.isRead)
    }

    /// A book added while offline must start with .pending sync status.
    /// This is the fundamental invariant of the offline-first pattern.
    func test_addBook_whileOffline_isPending() {
        monitor.simulateOffline = true

        viewModel.addBook(title: "Offline Book", author: "Author",
                          rating: 3, notes: "", isRead: false)

        XCTAssertEqual(viewModel.books.first?.syncStatus, .pending,
                       "Books created offline must start with .pending status")
    }

    /// Every newly created book (even when online) starts as .pending.
    /// It becomes .synced only after the server acknowledges it.
    func test_addBook_alwaysStartsPending() {
        monitor.simulateOffline = false  // simulate online

        viewModel.addBook(title: "Online Book", author: "Author",
                          rating: 3, notes: "", isRead: false)

        // Still pending — sync happens asynchronously and we're not awaiting it here
        XCTAssertEqual(viewModel.books.first?.syncStatus, .pending)
    }

    // MARK: - Delete Book Tests

    func test_deleteBook_removesFromStore() {
        viewModel.addBook(title: "To Delete", author: "Author",
                          rating: 1, notes: "", isRead: false)
        XCTAssertEqual(viewModel.books.count, 1)

        viewModel.deleteBook(viewModel.books[0])

        XCTAssertEqual(viewModel.books.count, 0)
    }

    func test_deleteBook_onlyRemovesTargetBook() {
        viewModel.addBook(title: "Keep Me",  author: "A", rating: 3, notes: "", isRead: false)
        viewModel.addBook(title: "Delete Me", author: "B", rating: 3, notes: "", isRead: false)
        XCTAssertEqual(viewModel.books.count, 2)

        let toDelete = viewModel.books.first { $0.title == "Delete Me" }!
        viewModel.deleteBook(toDelete)

        XCTAssertEqual(viewModel.books.count, 1)
        XCTAssertEqual(viewModel.books[0].title, "Keep Me")
    }

    // MARK: - Update Book Tests

    /// Editing a synced book must revert its status to .pending until re-synced.
    /// This is the "mark dirty on edit" rule that keeps data consistent.
    func test_updateBook_marksPending() {
        // Arrange: add a book and manually mark it as synced
        viewModel.addBook(title: "Original Title", author: "Author",
                          rating: 3, notes: "", isRead: false)

        let ctx = persistence.viewContext
        let request = BookEntity.fetchRequest()
        if let entity = (try? ctx.fetch(request))?.first {
            entity.syncStatus = SyncStatus.synced.rawValue
            entity.remoteId   = 42
            try? ctx.save()
        }
        viewModel.fetchBooks()
        XCTAssertEqual(viewModel.books[0].syncStatus, .synced)

        // Act: update the book
        viewModel.updateBook(viewModel.books[0],
                             title:  "Updated Title",
                             author: "Updated Author",
                             rating: 4, notes: "Changed", isRead: true)

        // Assert: edit marks it dirty
        XCTAssertEqual(viewModel.books[0].title,      "Updated Title")
        XCTAssertEqual(viewModel.books[0].syncStatus, .pending,
                       "An edited book must revert to .pending until re-synced")
    }

    // MARK: - Fetch / Sort Tests

    /// Books are sorted by createdAt descending (newest first).
    func test_fetchBooks_sortedNewestFirst() throws {
        // Add books with a tiny delay between them so createdAt differs
        viewModel.addBook(title: "First",  author: "A", rating: 3, notes: "", isRead: false)

        // Manually push the first book's createdAt back in time
        let ctx = persistence.viewContext
        let request = BookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", "First")
        if let entity = (try? ctx.fetch(request))?.first {
            entity.createdAt = Date().addingTimeInterval(-60)
            try? ctx.save()
        }

        viewModel.addBook(title: "Second", author: "B", rating: 3, notes: "", isRead: false)
        viewModel.fetchBooks()

        XCTAssertEqual(viewModel.books[0].title, "Second",
                       "Most recently added book should appear first")
        XCTAssertEqual(viewModel.books[1].title, "First")
    }

    // MARK: - Manual Sync Tests

    /// Calling manualSync while offline sets an error message instead of crashing.
    func test_manualSync_whileOffline_setsErrorMessage() {
        monitor.simulateOffline = true
        XCTAssertNil(viewModel.errorMessage)

        viewModel.manualSync()

        XCTAssertNotNil(viewModel.errorMessage,
                        "manualSync while offline must set an error message")
    }

    func test_manualSync_whileOnline_doesNotSetError() {
        monitor.simulateOffline = false

        viewModel.manualSync()

        XCTAssertNil(viewModel.errorMessage)
    }
}
