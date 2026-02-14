// Book.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// Pure Swift domain model — zero Core Data dependencies.
// ViewModels and Views work exclusively with this type.
// Core Data is an implementation detail hidden behind BookEntity+Extensions.swift.

import Foundation

// MARK: - Book Domain Model

/// A book in the user's reading list.
/// This is a value type (struct) that is safe to use from any thread.
struct Book: Identifiable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var rating: Int         // 1–5 stars
    var notes: String
    var isRead: Bool
    var syncStatus: SyncStatus
    var remoteId: Int64?    // nil until first successful sync with the server
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - Factory

extension Book {
    /// Creates a new book with sensible defaults.
    /// syncStatus starts as .pending because the book has not yet been sent to the server.
    static func new(title: String, author: String, rating: Int = 3,
                    notes: String = "", isRead: Bool = false) -> Book {
        let now = Date()
        return Book(
            id: UUID(),
            title: title,
            author: author,
            rating: rating,
            notes: notes,
            isRead: isRead,
            syncStatus: .pending,
            remoteId: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

// MARK: - Preview Fixtures

extension Book {
    static let previewSynced = Book(
        id: UUID(),
        title: "Clean Code",
        author: "Robert C. Martin",
        rating: 5,
        notes: "Essential reading for any software engineer.",
        isRead: true,
        syncStatus: .synced,
        remoteId: 1,
        createdAt: Date(),
        updatedAt: Date()
    )

    static let previewPending = Book(
        id: UUID(),
        title: "The Pragmatic Programmer",
        author: "Hunt & Thomas",
        rating: 5,
        notes: "Added while offline.",
        isRead: false,
        syncStatus: .pending,
        remoteId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    static let previewFailed = Book(
        id: UUID(),
        title: "Designing Data-Intensive Applications",
        author: "Martin Kleppmann",
        rating: 4,
        notes: "Sync failed — will retry.",
        isRead: false,
        syncStatus: .failed,
        remoteId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
