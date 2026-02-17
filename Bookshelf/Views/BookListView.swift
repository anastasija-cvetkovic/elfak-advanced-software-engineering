// BookListView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// The main screen of the app. Composes all other views and exposes the
// interactive demo controls used during a live tutorial presentation:
//
//   [Simulate Offline toggle] — immediately changes app behaviour without airplane mode
//   [Sync Log button]         — shows/hides the real-time operation log
//   [Add Sample Books button] — populates the list from JSONPlaceholder in one tap
//   [Pull-to-refresh]         — manually triggers the sync queue

import SwiftUI

struct BookListView: View {

    @State private var viewModel = BooksViewModel()
    @State private var showAddSheet  = false
    @State private var bookToEdit: Book? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                if viewModel.networkMonitor.effectivelyOnline {
                    Divider()
                }

                // Network status banner — slides in from top (gradient blends with nav bar)
                if !viewModel.networkMonitor.effectivelyOnline {
                    NetworkBannerView(networkMonitor: viewModel.networkMonitor)
                        .environment(\.colorScheme, .dark)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Sync log panel (collapsible)
                if viewModel.showSyncLog {
                    SyncLogView(entries: viewModel.syncService.syncLog)
                        .frame(height: viewModel.syncService.syncLog.isEmpty ? 44 : 200)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 2)
                        .animation(.easeInOut, value: viewModel.showSyncLog)
                }

                // Sync activity indicator (same as nav bar when online — systemBackground)
                if viewModel.syncService.isSyncing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                }

                // Book list
                if viewModel.books.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                            BookRowView(book: book)
                                .contentShape(Rectangle())
                                .onTapGesture { bookToEdit = book }
                                .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                                .listRowSeparator(index == viewModel.books.count - 1 ? .hidden : .visible, edges: .bottom)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { viewModel.deleteBook(viewModel.books[$0]) }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.manualSync()
                        viewModel.fetchBooks()
                    }
                }

                Divider()

                // Demo toolbar
                demoToolbar
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.networkMonitor.effectivelyOnline)
            .navigationTitle("Trusty Bookshelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                viewModel.networkMonitor.effectivelyOnline
                    ? Color(.systemBackground)
                    : Color(.systemGray4),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                viewModel.networkMonitor.effectivelyOnline ? .light : .dark,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    statsLabel
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditBookView(viewModel: viewModel)
            }
            .sheet(item: $bookToEdit) { book in
                AddEditBookView(viewModel: viewModel, book: book)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No books yet")
                .font(.headline)
            (Text("Tap ")
            + Text(Image(systemName: "plus"))
            + Text(" to add a book, or ")
            + Text(Image(systemName: "books.vertical.fill"))
            + Text(" to load demo data."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Stats Label

    private var statsLabel: some View {
        let pending = viewModel.books.filter { $0.syncStatus == .pending }.count
        let failed  = viewModel.books.filter { $0.syncStatus == .failed }.count
        return Group {
            if failed > 0 {
                Label("\(failed) failed", systemImage: "exclamationmark.icloud.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if pending > 0 {
                Label("\(pending) pending", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray3))
            } else if !viewModel.books.isEmpty {
                Label("All synced", systemImage: "checkmark.icloud.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Demo Toolbar

    private var demoToolbar: some View {
        HStack(spacing: 12) {

            // 1. Offline simulation toggle — the star demo feature
            Toggle(isOn: Binding(
                get: { viewModel.networkMonitor.simulateOffline },
                set: { viewModel.networkMonitor.simulateOffline = $0 }
            )) {
                Label(
                    viewModel.networkMonitor.simulateOffline ? "Go Online" : "Go Offline",
                    systemImage: viewModel.networkMonitor.simulateOffline ? "wifi" : "wifi.slash"
                )
                .font(.caption.weight(.medium))
            }
            .toggleStyle(.button)
            .tint(viewModel.networkMonitor.simulateOffline ? .green : Color(.systemGray3))

            Spacer()

            // 2. Sync log toggle
            Button {
                withAnimation { viewModel.showSyncLog.toggle() }
            } label: {
                Image(systemName: viewModel.showSyncLog
                      ? "list.clipboard.fill" : "list.clipboard")
                    .foregroundStyle(viewModel.showSyncLog ? Color.accentColor : Color.secondary)
            }
            .help("Toggle Sync Log")

            // 3. Load sample books from JSONPlaceholder
            Button {
                viewModel.addSampleBooks()
            } label: {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.secondary)
            }
            .help("Add Sample Books from JSONPlaceholder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview {
    BookListView()
        .environment(\.managedObjectContext,
                      PersistenceController.preview.viewContext)
}
