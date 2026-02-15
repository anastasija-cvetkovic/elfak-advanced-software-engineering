// SyncLogView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// An expandable panel showing a real-time log of sync operations.
// This is the most educational feature for a live demo — students can see exactly
// what happens when a book is created, synced, or fails.

import SwiftUI

struct SyncLogView: View {
    let entries: [SyncLogEntry]

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                Text("Sync Log")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(entries.isEmpty ? "No operations yet" : "\(entries.count) event(s)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))

            if !entries.isEmpty {
                Divider()
            }

            if entries.isEmpty {
                EmptyView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            LogEntryRow(entry: entry)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: SyncLogEntry

    var outcomeColor: Color {
        switch entry.outcome {
        case "SUCCESS": return .green
        case "FAILED":  return .red
        default:        return .orange
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(SyncLogView.timeFormatter.string(from: entry.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            // Operation + outcome
            Text("[\(entry.operation)]")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(outcomeColor)
                .frame(width: 96, alignment: .leading)

            // Book title + detail
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.bookTitle)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                Text(entry.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}

// MARK: - Preview

#Preview {
    SyncLogView(entries: [
        SyncLogEntry(timestamp: Date(),
                     bookTitle: "Clean Code",
                     operation: "CREATE",
                     outcome: "SUCCESS",
                     detail: "remoteId = 101"),
        SyncLogEntry(timestamp: Date().addingTimeInterval(-5),
                     bookTitle: "The Pragmatic Programmer",
                     operation: "SYNC",
                     outcome: "FAILED",
                     detail: "Network error: not connected"),
        SyncLogEntry(timestamp: Date().addingTimeInterval(-10),
                     bookTitle: "—",
                     operation: "SYNC START",
                     outcome: "QUEUED",
                     detail: "2 item(s) in queue")
    ])
    .frame(height: 200)
}
