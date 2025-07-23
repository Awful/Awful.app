//  ForumsListViewModel.swift
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

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsListViewModel")

@MainActor
final class ForumsListViewModel: NSObject, ObservableObject {
    @Published var sections: [ForumsSection] = []
    @Published var isRefreshing = false
    @Published var isEditing = false
    @Published var hasFavorites = false
    @Published var showUnreadAnnouncementsBadge = false
    @Published var tabBarBadgeValue: String?
    @Published var canSendPrivateMessages = false
    
    private let announcementsController: NSFetchedResultsController<Announcement>
    private let favoriteForumsController: NSFetchedResultsController<ForumMetadata>
    private let forumsController: NSFetchedResultsController<Forum>
    private let managedObjectContext: NSManagedObjectContext
    
    private var cancellables: Set<AnyCancellable> = []
    private var favoriteForumCountObserver: ManagedObjectCountObserver!
    private var unreadAnnouncementCountObserver: ManagedObjectCountObserver!
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.showUnreadAnnouncementsBadge) private var showUnreadAnnouncementsBadgeStorage
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessagesStorage
    
    private(set) lazy var undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()
    
    init(managedObjectContext: NSManagedObjectContext) throws {
        self.managedObjectContext = managedObjectContext
        
        // Setup announcements controller
        let announcementsRequest = Announcement.makeFetchRequest()
        announcementsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        announcementsController = NSFetchedResultsController(
            fetchRequest: announcementsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        // Setup favorite forums controller
        let favoriteForumsRequest = ForumMetadata.makeFetchRequest()
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        favoriteForumsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        // Setup forums controller
        let forumsRequest = Forum.makeFetchRequest()
        forumsRequest.predicate = NSPredicate(format: "%K == YES AND %K == NO", #keyPath(Forum.metadata.visibleInForumList), #keyPath(Forum.metadata.favorite))
        forumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true),
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]
        forumsController = NSFetchedResultsController(
            fetchRequest: forumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: #keyPath(Forum.group.sectionIdentifier),
            cacheName: nil)
        
        super.init()
        
        // Perform initial fetches
        try announcementsController.performFetch()
        try favoriteForumsController.performFetch()
        try forumsController.performFetch()
        
        // Set delegates
        announcementsController.delegate = self
        favoriteForumsController.delegate = self
        forumsController.delegate = self
        
        // Setup observers
        setupObservers()
        
        // Initial data load
        rebuildSections()
    }
    
    private func setupObservers() {
        favoriteForumCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: ForumMetadata.entityName,
            predicate: NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite)),
            didChange: { [weak self] favoriteCount in
                guard let self else { return }
                Task { @MainActor in
                    self.hasFavorites = favoriteCount > 0
                }
            })
        
        unreadAnnouncementCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: Announcement.entityName,
            predicate: NSPredicate(format: "%K == NO", #keyPath(Announcement.hasBeenSeen)),
            didChange: { [weak self] unreadCount in
                guard let self else { return }
                Task { @MainActor in
                    self.updateBadgeValue(unreadCount)
                }
            })
        
        // Bind settings
        $showUnreadAnnouncementsBadgeStorage
            .receive(on: RunLoop.main)
            .sink { [weak self] showBadge in
                guard let self else { return }
                self.showUnreadAnnouncementsBadge = showBadge
                self.updateBadgeValue(self.unreadAnnouncementCountObserver.count)
            }
            .store(in: &cancellables)
        
        $canSendPrivateMessagesStorage
            .receive(on: RunLoop.main)
            .assign(to: &$canSendPrivateMessages)
        
        // Initial values
        hasFavorites = favoriteForumCountObserver.count > 0
        showUnreadAnnouncementsBadge = showUnreadAnnouncementsBadgeStorage
        canSendPrivateMessages = canSendPrivateMessagesStorage
        updateBadgeValue(unreadAnnouncementCountObserver.count)
    }
    
    private func updateBadgeValue(_ unreadCount: Int) {
        tabBarBadgeValue = {
            guard showUnreadAnnouncementsBadge else { return nil }
            return unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }()
    }
    
    func refresh() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        do {
            try await ForumsClient.shared.taxonomizeForums()
            RefreshMinder.sharedMinder.didRefresh(.forumList)
            migrateFavoriteForumsFromSettings()
        } catch {
            logger.error("Could not taxonomize forums: \(error)")
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    private func migrateFavoriteForumsFromSettings() {
        if let forumIDs = SettingsMigration.favoriteForums(.standard) {
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs: forumIDs.map(\.rawValue), in: managedObjectContext)
            for (i, metadata) in zip(0..., metadatas) {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            do {
                try managedObjectContext.save()
            }
            catch {
                fatalError("error saving: \(error)")
            }
            SettingsMigration.forgetFavoriteForums(.standard)
        }
    }
    
    var nextFavoriteIndex: Int32 {
        let last = favoriteForumsController.fetchedObjects?.last
        return last.map { $0.favoriteIndex + 1 } ?? 1
    }
}

// MARK: - Section Management

extension ForumsListViewModel {
    private func rebuildSections() {
        var newSections: [ForumsSection] = []
        
        // Add announcements section
        if let announcementObjects = announcementsController.fetchedObjects, !announcementObjects.isEmpty {
            let items = announcementObjects.map { ForumItem.announcement($0) }
            newSections.append(ForumsSection(
                title: LocalizedString("forums-list.announcements-section-title"),
                items: items,
                type: .announcements
            ))
        }
        
        // Add favorites section
        if let favoriteObjects = favoriteForumsController.fetchedObjects, !favoriteObjects.isEmpty {
            let items = favoriteObjects.map { ForumItem.forum($0.forum) }
            newSections.append(ForumsSection(
                title: LocalizedString("forums-list.favorite-forums.section-title"),
                items: items,
                type: .favorites
            ))
        }
        
        // Add forum sections
        if let sections = forumsController.sections {
            for section in sections {
                let sectionIdentifier = section.name
                let title = String(sectionIdentifier.dropFirst(ForumGroup.sectionIdentifierIndexLength + 1))
                let forums = section.objects as? [Forum] ?? []
                let items = forums.map { ForumItem.forum($0) }
                
                if !items.isEmpty {
                    newSections.append(ForumsSection(
                        title: title,
                        items: items,
                        type: .forums
                    ))
                }
            }
        }
        
        self.sections = newSections
    }
}

// MARK: - User Actions

extension ForumsListViewModel {
    func toggleFavorite(for forum: Forum) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        if forum.metadata.favorite {
            forum.metadata.favorite = false
        } else {
            forum.metadata.favorite = true
            forum.metadata.favoriteIndex = nextFavoriteIndex
        }
        forum.tickleForFetchedResultsController()
        
        try! forum.managedObjectContext!.save()
    }
    
    func toggleExpansion(for forum: Forum) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        if forum.metadata.showsChildrenInForumList {
            forum.collapse()
        } else {
            forum.expand()
        }
        
        try! forum.managedObjectContext!.save()
    }
    
    func removeFavorite(_ forum: Forum) {
        forum.metadata.favorite = false
        forum.tickleForFetchedResultsController()
        try! forum.managedObjectContext!.save()
        
        undoManager.registerUndo(withTarget: self) { viewModel in
            forum.metadata.favorite = true
            forum.tickleForFetchedResultsController()
            try! forum.managedObjectContext!.save()
        }
        undoManager.setActionName(LocalizedString("forums-list.undo-action.remove-favorite"))
    }
    
    func moveFavorite(from source: IndexSet, to destination: Int) {
        guard let favoriteSection = sections.first(where: { $0.type == .favorites }),
              let sectionIndex = sections.firstIndex(where: { $0.type == .favorites }) else { return }
        
        var items = favoriteSection.items
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update the section
        sections[sectionIndex] = ForumsSection(
            title: favoriteSection.title,
            items: items,
            type: .favorites
        )
        
        // Update Core Data
        let forums = items.compactMap { item in
            if case .forum(let forum) = item {
                return forum
            }
            return nil
        }
        
        for (index, forum) in forums.enumerated() {
            forum.metadata.favoriteIndex = Int32(index + 1)
        }
        
        try! managedObjectContext.save()
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ForumsListViewModel: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor in
            rebuildSections()
        }
    }
}

// MARK: - Data Models

struct ForumsSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [ForumItem]
    let type: SectionType
    
    enum SectionType {
        case announcements
        case favorites
        case forums
    }
}

enum ForumItem: Identifiable {
    case announcement(Announcement)
    case forum(Forum)
    
    var id: String {
        switch self {
        case .announcement(let announcement):
            return "announcement-\(announcement.objectID)"
        case .forum(let forum):
            return "forum-\(forum.objectID)"
        }
    }
    
    var forum: Forum? {
        if case .forum(let forum) = self {
            return forum
        }
        return nil
    }
    
    var announcement: Announcement? {
        if case .announcement(let announcement) = self {
            return announcement
        }
        return nil
    }
}
