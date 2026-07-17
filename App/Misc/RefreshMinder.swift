//  RefreshMinder.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import Foundation

final class RefreshMinder {
    private let userDefaults: UserDefaults
    
    private init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    static let sharedMinder = RefreshMinder(userDefaults: .standard)
    
    func shouldRefreshForum(_ forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > forumTimeBetweenRefreshes
    }
    
    func didRefreshForum(_ forum: Forum) {
        forum.lastRefresh = Date()
    }
    
    func shouldRefreshFilteredForum(_ forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastFilteredRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > forumTimeBetweenRefreshes
    }
    
    func didRefreshFilteredForum(_ forum: Forum) {
        forum.lastFilteredRefresh = Date()
    }
    
    func forgetForum(_ forum: Forum) {
        forum.lastRefresh = nil
        forum.lastFilteredRefresh = nil
    }

    /// Clears every forum's thread-list refresh timestamps so each reloads the next time it's viewed.
    /// Used when the archives timeframe changes — that invalidates the cached (wrong-timeframe) threads
    /// for every forum, not just the one on screen.
    func forgetAllForums(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<Forum>(entityName: Forum.entityName)
        request.predicate = NSPredicate(format: "lastRefresh != nil OR lastFilteredRefresh != nil")
        guard let forums = try? context.fetch(request), !forums.isEmpty else { return }
        for forum in forums {
            forum.lastRefresh = nil
            forum.lastFilteredRefresh = nil
        }
        if context.hasChanges {
            try? context.save()
        }
    }
    
    func forgetEverything() {
        Refresh.all.forEach { userDefaults.removeObject(forKey: $0.key) }
    }
    
    struct Refresh {
        fileprivate let key: String
        fileprivate let interval: TimeInterval

        private init(key: String, interval: TimeInterval) {
            self.key = key
            self.interval = interval
        }

        static let accountFeatures = Refresh(key: "LastAccountFeaturesRefreshDate", interval: 60 * 15)
        static let announcements = Refresh(key: "com.awfulapp.Awful.LastAnnouncementsRefreshDate", interval: 60 * 60 * 20)
        static let avatar = Refresh(key: "LastLoggedInUserAvatarRefreshDate", interval: 60 * 10)
        static let bookmarks = Refresh(key: "com.awfulapp.Awful.LastBookmarksRefreshDate", interval: 60 * 10)
        static let externalStylesheet = Refresh(key: "LastExternalStylesheetRefreshDate", interval: 60 * 60)
        static let forumList = Refresh(key: "com.awfulapp.Awful.LastForumRefreshDate", interval: 60 * 60 * 6)
        static let lepersColony = Refresh(key: "com.awfulapp.Awful.LastLepersColonyRefreshDate", interval: 60 * 5)
        static let loggedInUser = Refresh(key: "LastLoggedInUserRefreshDate", interval: 60 * 5)
        static let privateMessagesInbox = Refresh(key: "LastPrivateMessageInboxRefreshDate", interval: 60 * 10)

        static var all: [Refresh] {
            return [.accountFeatures, .announcements, .avatar, .bookmarks, .externalStylesheet, .forumList, .lepersColony, .loggedInUser, .privateMessagesInbox]
        }
    }
    
    func shouldRefresh(_ r: Refresh) -> Bool {
        guard let lastRefresh = userDefaults.object(forKey: r.key) as? Date else { return true }
        return Date().timeIntervalSince(lastRefresh) > r.interval
    }
    
    func didRefresh(_ r: Refresh) {
        userDefaults.set(Date(), forKey: r.key)
    }
    
    func suggestedRefreshDate(_ r: Refresh) -> Date {
        guard let lastRefresh = userDefaults.object(forKey: r.key) as? Date else {
            return Date().addingTimeInterval(timeBetweenInitialRefreshes())
        }
        let sinceLastRefresh = -lastRefresh.timeIntervalSinceNow
        if sinceLastRefresh > r.interval + 1 {
            return Date()
        }
        return Date().addingTimeInterval(r.interval - sinceLastRefresh)
    }
}

private let forumTimeBetweenRefreshes: TimeInterval = 60 * 15

private func timeBetweenInitialRefreshes() -> TimeInterval {
    return 120 + TimeInterval(arc4random_uniform(120))
}
