//  BookmarksListViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookmarksListViewModel")

@MainActor
final class BookmarksListViewModel: NSObject, ObservableObject {
    @Published var threads: [ThreadRowViewModel] = []
    @Published var isRefreshing = false
    @Published var canLoadMore: Bool = false
    @Published var isEditing = false
    
    private let managedObjectContext: NSManagedObjectContext
    private var cancellables: Set<AnyCancellable> = []
    private var latestPage = 0
    private var resultsController: NSFetchedResultsController<AwfulThread>?
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.bookmarksSortedUnread) private var sortUnreadToTop
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    
    private(set) lazy var undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()
    
    init(managedObjectContext: NSManagedObjectContext) throws {
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        // Setup results controller
        try setupResultsController()
        
        // Setup observers for settings changes
        setupObservers()
        
        // Initial data load
        updateThreads()
    }
    
    private func setupResultsController() throws {
        let fetchRequest = AwfulThread.makeFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == YES && %K > 0", #keyPath(AwfulThread.bookmarked), #keyPath(AwfulThread.bookmarkListPage))
        
        fetchRequest.sortDescriptors = {
            var descriptors = [NSSortDescriptor(key: #keyPath(AwfulThread.bookmarkListPage), ascending: true)]
            if sortUnreadToTop {
                descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.anyUnreadPosts), ascending: false))
            }
            descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.lastPostDate), ascending: false))
            return descriptors
        }()
        
        resultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        resultsController?.delegate = self
        try resultsController?.performFetch()
    }
    
    private func setupObservers() {
        Publishers.Merge(
            $showThreadTags.dropFirst(),
            $sortUnreadToTop.dropFirst()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            guard let self else { return }
            do {
                try setupResultsController()
                updateThreads()
            } catch {
                logger.error("Failed to update results controller: \(error)")
            }
        }
        .store(in: &cancellables)
    }
    
    private func updateThreads() {
        guard let resultsController = resultsController else {
            threads = []
            return
        }
        
        let theme = Theme.defaultTheme()
        let placeholder = ThreadTagLoader.Placeholder.thread(tintColor: nil)
        
        threads = (resultsController.fetchedObjects ?? []).map { thread in
            ThreadRowViewModel(
                thread: thread,
                theme: theme,
                showsTagAndRating: showThreadTags,
                ignoreSticky: true,
                placeholder: placeholder
            )
        }
    }
    
    func refresh() async throws {
        logger.info("🔄 BookmarksListViewModel.refresh() called")
        isRefreshing = true
        
        do {
            let threads = try await ForumsClient.shared.listBookmarkedThreads(page: 1)
            latestPage = 1
            RefreshMinder.sharedMinder.didRefresh(.bookmarks)
            
            if threads.count >= 40 {
                enableLoadMore()
            } else {
                disableLoadMore()
            }
            
            // Force the results controller to refetch after network update
            try resultsController?.performFetch()
            updateThreads()
            logger.info("✅ BookmarksListViewModel.refresh() completed successfully")
            
        } catch {
            logger.error("Failed to refresh bookmarks: \(error)")
            isRefreshing = false
            throw error
        }
        
        isRefreshing = false
    }
    
    func loadMore() async throws {
        guard canLoadMore else { return }
        
        do {
            let threads = try await ForumsClient.shared.listBookmarkedThreads(page: latestPage + 1)
            latestPage += 1
            
            if threads.count < 40 {
                disableLoadMore()
            }
        } catch {
            logger.error("Failed to load more bookmarks: \(error)")
            throw error
        }
    }
    
    private func enableLoadMore() {
        canLoadMore = true
    }
    
    private func disableLoadMore() {
        canLoadMore = false
    }
    
    func toggleBookmark(for thread: AwfulThread) async throws {
        try await ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
        
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    func deleteThread(_ thread: AwfulThread) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        setThread(thread, isBookmarked: false)
    }
    
    @objc private func setThread(_ thread: AwfulThread, isBookmarked: Bool) {
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = isBookmarked
        
        Task {
            do {
                try await ForumsClient.shared.setThread(thread, isBookmarked: isBookmarked)
            } catch {
                logger.error("Failed to update bookmark status: \(error)")
                // TODO: Handle error - maybe show alert or revert changes
            }
        }
    }
    
    func thread(for viewModel: ThreadRowViewModel) -> AwfulThread? {
        return resultsController?.fetchedObjects?.first { $0.threadID == viewModel.id }
    }
    
    func toggleEditing() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        isEditing.toggle()
    }
    
    // MARK: - Handoff Support
    
    func prepareUserActivity() -> NSUserActivity? {
        guard handoffEnabled else { return nil }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        activity.route = .bookmarks
        activity.title = LocalizedString("handoff.bookmarks-title")
        activity.needsSave = true
        
        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
        return activity
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension BookmarksListViewModel: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor in
            updateThreads()
        }
    }
}