// BookRowView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// Displays a single book row with:
//   - Title and author
//   - Star rating
//   - "Read" badge
//   - Sync status icon (the key visual indicator for offline-first state)

import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Left: book info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Star rating — only shown if the book has been rated
                if book.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= book.rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }

            Spacer()

            // Right: status indicators — all icons on the same horizontal line
            HStack(alignment: .center, spacing: 8) {

                if book.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .help("Read")
                }

                // Sync status icon — the core educational element
                // Each icon represents a state in the offline-first sync state machine:
                //   clock.arrow.circlepath      = pending (waiting to sync)
                //   checkmark.icloud.fill       = synced  (on the server)
                //   exclamationmark.icloud.fill = failed  (will retry)
                Image(systemName: book.syncStatus.systemImage)
                    .foregroundStyle(book.syncStatus.color)
                    .font(.title3)
                    .help(book.syncStatus.label)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("All sync states") {
    List {
        BookRowView(book: .previewSynced)
        BookRowView(book: .previewPending)
        BookRowView(book: .previewFailed)
    }
}
