//  SwiftUIBookmarksView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import SwiftUI

struct SwiftUIBookmarksView: View {
    @StateObject private var viewModel: BookmarksListViewModel
    @SwiftUI.Environment(\.theme) private var theme
    var coordinator: (any MainCoordinator)?
    
    @State private var isLoadingMore = false
    @State private var error: Error?
    @State private var showingError = false
    
    init(managedObjectContext: NSManagedObjectContext, coordinator: (any MainCoordinator)? = nil) {
        self._viewModel = StateObject(wrappedValue: {
            do {
                return try BookmarksListViewModel(managedObjectContext: managedObjectContext)
            } catch {
                fatalError("Failed to create BookmarksListViewModel: \(error)")
            }
        }())
        self.coordinator = coordinator
    }
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationHeaderView(
                title: "Bookmarks",
                rightButton: HeaderButton(text: viewModel.isEditing ? "Done" : "Edit") {
                    viewModel.toggleEditing()
                }
            )
            
            bookmarksList
        }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Handle Core Data context saves if needed
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
        .themed()
    }
    
    private var bookmarksList: some View {
        List {
            ForEach(viewModel.threads) { threadViewModel in
                ThreadRowView(
                    viewModel: threadViewModel,
                    onTap: {
                        handleThreadTap(threadViewModel)
                    },
                    onBookmarkToggle: {
                        handleBookmarkToggle(threadViewModel)
                    }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color(theme[uicolor: "listSeparatorColor"] ?? UIColor.separator))
                .background(Color.clear)
                .deleteDisabled(!viewModel.isEditing)
            }
            .onDelete(perform: viewModel.isEditing ? deleteThreads : nil)
            
            // Load more indicator
            if viewModel.canLoadMore && !viewModel.threads.isEmpty {
                LoadMoreView(isLoading: isLoadingMore) {
                    await loadMore()
                }
            }
        }
        .listStyle(.plain)
        .background(backgroundColor)
        .scrollContentBackground(.hidden)
        .refreshable {
            await refresh()
        }
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
    }
    
    private var backgroundColor: Color {
        Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    private func handleViewAppear() {
        // Check if refresh is needed
        if viewModel.threads.isEmpty || RefreshMinder.sharedMinder.shouldRefresh(.bookmarks) {
            Task {
                await refresh()
            }
        }
    }
    
    private func handleViewDisappear() {
        viewModel.undoManager.removeAllActions()
    }
    
    private func handleThreadTap(_ threadViewModel: ThreadRowViewModel) {
        guard let thread = viewModel.thread(for: threadViewModel) else { return }
        
        let page: ThreadPage = thread.beenSeen ? .nextUnread : .first
        let threadDestination = ThreadDestination(
            thread: thread,
            page: page,
            author: nil,
            scrollFraction: nil,
            jumpToPostID: nil
        )
        NotificationCenter.default.post(name: Notification.Name("NavigateToThread"), object: threadDestination)
    }
    
    private func handleBookmarkToggle(_ threadViewModel: ThreadRowViewModel) {
        guard let thread = viewModel.thread(for: threadViewModel) else { return }
        
        Task {
            do {
                try await viewModel.toggleBookmark(for: thread)
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    private func deleteThreads(at offsets: IndexSet) {
        for index in offsets {
            let threadViewModel = viewModel.threads[index]
            if let thread = viewModel.thread(for: threadViewModel) {
                viewModel.deleteThread(thread)
            }
        }
    }
    
    @MainActor
    private func refresh() async {
        do {
            try await viewModel.refresh()
        } catch {
            self.error = error
            self.showingError = true
        }
    }
    
    @MainActor
    private func loadMore() async {
        isLoadingMore = true
        
        do {
            try await viewModel.loadMore()
        } catch {
            self.error = error
            self.showingError = true
        }
        
        isLoadingMore = false
    }
}

#Preview {
    // Create a mock managed object context for preview
    let container: NSPersistentContainer = NSPersistentContainer(name: "DataModel")
    let context: NSManagedObjectContext = container.viewContext
    
    return SwiftUIBookmarksView(
        managedObjectContext: context
    )
    .themed()
}