//  ThreadsListViewModel.swift
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

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadsListViewModel")

@MainActor
final class ThreadsListViewModel: NSObject, ObservableObject {
    @Published var threads: [ThreadRowViewModel] = []
    @Published var isRefreshing = false
    @Published var canLoadMore: Bool = false
    @Published var filterThreadTag: ThreadTag?
    @Published var canCompose: Bool = false
    
    let forum: Forum
    private let managedObjectContext: NSManagedObjectContext
    private var cancellables: Set<AnyCancellable> = []
    private var latestPage = 0
    private var resultsController: NSFetchedResultsController<AwfulThread>?
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.forumThreadsSortedUnread) private var sortUnreadThreadsToTop
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    
    private(set) lazy var undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()
    
    init(forum: Forum, managedObjectContext: NSManagedObjectContext) throws {
        self.forum = forum
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        // Setup results controller
        try setupResultsController()
        
        // Setup observers for settings changes
        setupObservers()
        
        // Initial data load
        updateThreads()
        updateCanCompose()
    }
    
    private func setupResultsController() throws {
        var filter: Set<ThreadTag> = []
        if let tag = filterThreadTag {
            filter.insert(tag)
        }
        
        let fetchRequest = AwfulThread.makeFetchRequest()
        fetchRequest.predicate = {
            var predicates = [NSPredicate(format: "%K > 0 && %K == %@", #keyPath(AwfulThread.threadListPage), #keyPath(AwfulThread.forum), forum)]
            if !filter.isEmpty {
                predicates.append(NSPredicate(format: "%K IN %@", #keyPath(AwfulThread.threadTag), filter))
            }
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }()
        
        fetchRequest.sortDescriptors = {
            var descriptors = [
                NSSortDescriptor(key: #keyPath(AwfulThread.stickyIndex), ascending: true),
                NSSortDescriptor(key: #keyPath(AwfulThread.threadListPage), ascending: true)]
            if sortUnreadThreadsToTop {
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
        Publishers.Merge3(
            $showThreadTags.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $sortUnreadThreadsToTop.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $filterThreadTag.dropFirst().map { _ in () }.eraseToAnyPublisher()
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
        
        let theme = Theme.currentTheme(for: ForumID(forum.forumID))
        let placeholder = ThreadTagLoader.Placeholder.thread(in: forum)
        
        threads = (resultsController.fetchedObjects ?? []).map { thread in
            ThreadRowViewModel(
                thread: thread,
                theme: theme,
                showsTagAndRating: showThreadTags,
                ignoreSticky: false,
                placeholder: placeholder
            )
        }
    }
    
    private func updateCanCompose() {
        canCompose = forum.canPost && forum.lastRefresh != nil
    }
    
    func refresh() async throws {
        isRefreshing = true
        
        do {
            _ = try await ForumsClient.shared.listThreads(in: forum, tagged: filterThreadTag, page: 1)
            latestPage = 1
            enableLoadMore()
            
            if filterThreadTag == nil {
                RefreshMinder.sharedMinder.didRefreshForum(forum)
            } else {
                RefreshMinder.sharedMinder.didRefreshFilteredForum(forum)
            }
            
            // Announcements appear in all thread lists
            RefreshMinder.sharedMinder.didRefresh(.announcements)
            
            updateCanCompose()
        } catch {
            logger.error("Failed to refresh threads: \(error)")
            isRefreshing = false
            throw error
        }
        
        isRefreshing = false
    }
    
    func loadMore() async throws {
        guard canLoadMore else { return }
        
        do {
            _ = try await ForumsClient.shared.listThreads(in: forum, tagged: filterThreadTag, page: latestPage + 1)
            latestPage += 1
        } catch {
            logger.error("Failed to load more threads: \(error)")
            throw error
        }
    }
    
    private func enableLoadMore() {
        canLoadMore = true
    }
    
    func toggleBookmark(for thread: AwfulThread) async throws {
        try await ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
        
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    func setFilter(threadTag: ThreadTag?) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        filterThreadTag = threadTag
        RefreshMinder.sharedMinder.forgetForum(forum)
    }
    
    func thread(for viewModel: ThreadRowViewModel) -> AwfulThread? {
        return resultsController?.fetchedObjects?.first { $0.threadID == viewModel.id }
    }
    
    // MARK: - Handoff Support
    
    func prepareUserActivity() -> NSUserActivity? {
        guard handoffEnabled else { return nil }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        activity.route = .forum(id: forum.forumID)
        activity.title = forum.name
        activity.needsSave = true
        
        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
        return activity
    }
    
    // MARK: - Compose Support
    
    func createComposeViewController() -> ThreadComposeViewController {
        let composeViewController = ThreadComposeViewController(forum: forum)
        composeViewController.restorationIdentifier = "New thread composition"
        return composeViewController
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ThreadsListViewModel: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor in
            updateThreads()
        }
    }
}