// SyncStatus.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// Defines the sync state machine for each book.
// Stored as a String in Core Data (Core Data has no native enum type).
// The Swift layer converts between String <-> SyncStatus for type safety.

import Foundation
import SwiftUI

// MARK: - SyncStatus Enum

/// Represents the current synchronization state of a locally stored book.
///
/// State transitions:
///   .pending  →  sync attempt  →  .synced   (success)
///   .pending  →  sync attempt  →  .failed   (network error)
///   .failed   →  next sync     →  .synced   (retry succeeds)
enum SyncStatus: String, CaseIterable {
    case pending = "pending"  // Created/modified locally, not yet sent to server
    case synced  = "synced"   // Server has acknowledged this record
    case failed  = "failed"   // Last sync attempt failed; will retry on next sync

    // System icon name for SwiftUI Image(systemName:)
    var systemImage: String {
        switch self {
        case .pending: return "clock.arrow.circlepath"
        case .synced:  return "checkmark.icloud.fill"
        case .failed:  return "exclamationmark.icloud.fill"
        }
    }

    // Color used for the status icon
    var color: Color {
        switch self {
        case .pending: return Color(.systemGray3)
        case .synced:  return .green
        case .failed:  return .red
        }
    }

    // Short human-readable label
    var label: String {
        switch self {
        case .pending: return "Pending sync"
        case .synced:  return "Synced"
        case .failed:  return "Sync failed"
        }
    }
}

// MARK: - SyncLogEntry

/// A single entry in the sync operation history log.
/// Shown in SyncLogView for educational/demo purposes.
struct SyncLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bookTitle: String
    let operation: String   // "CREATE", "UPDATE", "DELETE"
    let outcome: String     // "SUCCESS", "FAILED", "QUEUED"
    let detail: String      // e.g. "remoteId = 42" or error message
}
