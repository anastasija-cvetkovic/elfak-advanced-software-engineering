// BookEntity+Extensions.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// This file is the translation layer between Core Data (BookEntity NSManagedObject)
// and the pure Swift domain model (Book struct).
//
// WHY THIS PATTERN?
//   If Views and ViewModels imported BookEntity directly, they would depend on
//   Core Data. That makes unit testing hard (you need a Core Data stack for every test).
//   By converting to Book structs at this boundary, all other code is pure Swift —
//   testable without any Core Data setup.

import CoreData

extension BookEntity {

    // MARK: - NSManagedObject → Domain Model

    /// Converts this Core Data entity into a pure Swift Book value.
    func toDomainModel() -> Book {
        Book(
            id:         id ?? UUID(),
            title:      title ?? "",
            author:     author ?? "",
            rating:     Int(rating),
            notes:      notes ?? "",
            isRead:     isRead,
            syncStatus: SyncStatus(rawValue: syncStatus ?? "pending") ?? .pending,
            remoteId:   remoteId == 0 ? nil : remoteId,
            createdAt:  createdAt ?? Date(),
            updatedAt:  updatedAt ?? Date()
        )
    }

    // MARK: - Domain Model → NSManagedObject

    /// Updates this entity's properties from a Book domain value.
    /// Called by BooksViewModel when adding or editing a book.
    func update(from book: Book) {
        self.id         = book.id
        self.title      = book.title
        self.author     = book.author
        self.rating     = Int16(book.rating)
        self.notes      = book.notes
        self.isRead     = book.isRead
        self.syncStatus = book.syncStatus.rawValue
        // 0 is the sentinel "no remote ID" value (Core Data has no optional scalars)
        self.remoteId   = book.remoteId ?? 0
        self.createdAt  = book.createdAt
        self.updatedAt  = book.updatedAt
    }
}
