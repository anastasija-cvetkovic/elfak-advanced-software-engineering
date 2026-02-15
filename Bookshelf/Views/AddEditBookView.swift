// AddEditBookView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// A sheet used for both adding a new book (book == nil) and editing an existing one.
//
// KEY EDUCATIONAL DETAIL:
//   The form shows a live hint at the bottom:
//     "Will sync immediately ✓"   — if the network is available
//     "Will queue as ⏳ pending"  — if offline (or simulate toggle is on)
//   This makes the offline-first behaviour visible before the user even taps Save.

import SwiftUI

struct AddEditBookView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BooksViewModel
    var book: Book? = nil  // nil = Add mode, non-nil = Edit mode

    @State private var title: String  = ""
    @State private var author: String = ""
    @State private var rating: Int    = 3
    @State private var notes: String  = ""
    @State private var isRead: Bool   = false
    @State private var showDeleteConfirm = false

    var isEditing: Bool { book != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    Toggle("I've Read This", isOn: $isRead)
                }

                Section("Rating") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(isRead ? Color.yellow : Color(.systemGray4))
                                .onTapGesture { rating = star }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isRead)
                }
                .opacity(isRead ? 1 : 0.4)

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Delete button — only shown in edit mode
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Book")
                                Spacer()
                            }
                        }
                    }
                }

                // Offline-first hint — educational / interactive element
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.networkMonitor.effectivelyOnline
                              ? "checkmark.icloud.fill"
                              : "clock.arrow.circlepath")
                            .foregroundStyle(viewModel.networkMonitor.effectivelyOnline
                                             ? Color.green : Color(.systemGray3))
                        Text(viewModel.networkMonitor.effectivelyOnline
                             ? "Will sync immediately"
                             : "Will queue as pending (offline)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync Preview")
                }
            }
            .navigationTitle(isEditing ? "Edit Book" : "New Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete \"\(title)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let book { viewModel.deleteBook(book) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                if let book {
                    title  = book.title
                    author = book.author
                    rating = book.rating
                    notes  = book.notes
                    isRead = book.isRead
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedTitle  = title.trimmingCharacters(in: .whitespaces)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespaces)
        let effectiveRating = isRead ? rating : 0

        if isEditing, let book {
            viewModel.updateBook(book, title: trimmedTitle, author: trimmedAuthor,
                                 rating: effectiveRating, notes: notes, isRead: isRead)
        } else {
            viewModel.addBook(title: trimmedTitle, author: trimmedAuthor,
                              rating: effectiveRating, notes: notes, isRead: isRead)
        }
    }
}

// MARK: - Preview

#Preview("Add mode") {
    AddEditBookView(viewModel: BooksViewModel(persistence: .preview))
}
