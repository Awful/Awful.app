//  MessageListViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageListViewModel")

@MainActor
final class MessageListViewModel: NSObject, ObservableObject {
    @Published var messages: [MessageRowViewModel] = []
    @Published var isRefreshing = false
    @Published var unreadCount = 0
    @Published var tabBarBadgeValue: String?
    
    private let managedObjectContext: NSManagedObjectContext
    private var cancellables: Set<AnyCancellable> = []
    private var resultsController: NSFetchedResultsController<PrivateMessage>?
    private var unreadCountObserver: ManagedObjectCountObserver?
    
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorage(Settings.enableHaptics) var enableHaptics
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    
    init(managedObjectContext: NSManagedObjectContext) throws {
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        // Setup results controller
        try setupResultsController()
        
        // Setup unread count observer
        setupUnreadCountObserver()
        
        // Setup observers for settings changes
        setupObservers()
        
        // Initial data load
        updateMessages()
    }
    
    private func setupResultsController() throws {
        let fetchRequest = PrivateMessage.makeFetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PrivateMessage.sentDate), ascending: false)
        ]
        
        resultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        resultsController?.delegate = self
        try resultsController?.performFetch()
    }
    
    private func setupUnreadCountObserver() {
        let updateBadgeValue = { [weak self] (unreadCount: Int) -> Void in
            self?.unreadCount = unreadCount
            self?.updateTabBarBadge(unreadCount)
        }
        
        unreadCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: PrivateMessage.entityName,
            predicate: NSPredicate(format: "%K == NO", #keyPath(PrivateMessage.seen)),
            didChange: updateBadgeValue
        )
        
        let initialCount = unreadCountObserver?.count ?? 0
        unreadCount = initialCount
        updateTabBarBadge(initialCount)
    }
    
    private func updateTabBarBadge(_ unreadCount: Int) {
        Task { @MainActor in
            tabBarBadgeValue = unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }
    }
    
    private func setupObservers() {
        $showThreadTags
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMessages()
            }
            .store(in: &cancellables)
    }
    
    @MainActor private func updateMessages() {
        guard let resultsController = resultsController,
              let fetchedObjects = resultsController.fetchedObjects else {
            messages = []
            return
        }
        
        let theme = Theme.defaultTheme()
        messages = fetchedObjects.map { message in
            MessageRowViewModel(
                message: message,
                theme: theme,
                showsThreadTags: showThreadTags
            )
        }
    }
    
    func refresh() async throws {
        guard canSendPrivateMessages else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            _ = try await ForumsClient.shared.listPrivateMessagesInInbox()
            RefreshMinder.sharedMinder.didRefresh(.privateMessagesInbox)
        } catch {
            logger.error("Failed to refresh messages: \(error)")
            throw error
        }
    }
    
    func shouldRefresh() -> Bool {
        guard canSendPrivateMessages else { return false }
        
        // Check if we have no messages
        if messages.isEmpty {
            return true
        }
        
        // Check refresh minder
        return RefreshMinder.sharedMinder.shouldRefresh(.privateMessagesInbox)
    }
    
    func deleteMessage(_ message: PrivateMessage) async throws {
        logger.debug("deleting message: \(message.messageID)")
        
        // Delete from Core Data context
        managedObjectContext.delete(message)
        
        // Delete from server
        try await ForumsClient.shared.deletePrivateMessage(message)
    }
    
    func message(at index: Int) -> PrivateMessage? {
        guard let resultsController = resultsController,
              let fetchedObjects = resultsController.fetchedObjects,
              index < fetchedObjects.count else {
            return nil
        }
        return fetchedObjects[index]
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MessageListViewModel: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor in
            updateMessages()
        }
    }
}