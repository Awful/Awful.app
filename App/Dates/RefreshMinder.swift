//  RefreshMinder.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class RefreshMinder: NSObject {
    fileprivate let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    static let sharedMinder = RefreshMinder(userDefaults: UserDefaults.standard)
    
    func shouldRefreshForum(_ forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastRefresh else { return true }
        return NSDate().timeIntervalSince(lastRefresh as Date) > forumTimeBetweenRefreshes
    }
    
    func didRefreshForum(_ forum: Forum) {
        forum.lastRefresh = Date() as NSDate
    }
    
    func shouldRefreshFilteredForum(_ forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastFilteredRefresh else { return true }
        return NSDate().timeIntervalSince(lastRefresh as Date) > forumTimeBetweenRefreshes
    }
    
    func didRefreshFilteredForum(_ forum: Forum) {
        forum.lastFilteredRefresh = Date() as NSDate
    }
    
    func forgetForum(_ forum: Forum) {
        forum.lastRefresh = nil
        forum.lastFilteredRefresh = nil
    }
    
    func forgetEverything() {
        Refresh.all.forEach { userDefaults.removeObject(forKey: $0.key) }
    }
    
    enum Refresh {
        case avatar
        case bookmarks
        case externalStylesheet
        case forumList
        case loggedInUser
        case newPrivateMessages
        case privateMessagesInbox
        
        fileprivate var key: String {
            switch self {
            case .avatar: return "LastLoggedInUserAvatarRefreshDate"
            case .bookmarks: return "com.awfulapp.Awful.LastBookmarksRefreshDate"
            case .externalStylesheet: return "LastExternalStylesheetRefreshDate"
            case .forumList: return "com.awfulapp.Awful.LastForumRefreshDate"
            case .loggedInUser: return "LastLoggedInUserRefreshDate"
            case .newPrivateMessages: return "com.awfulapp.Awful.LastMessageCheckDate"
            case .privateMessagesInbox: return "LastPrivateMessageInboxRefreshDate"
            }
        }
        
        fileprivate var timeBetweenRefreshes: TimeInterval {
            switch self {
            case .avatar: return 60 * 10
            case .bookmarks: return 60 * 10
            case .externalStylesheet: return 60 * 60
            case .forumList: return 60 * 60 * 6
            case .loggedInUser: return 60 * 5
            case .newPrivateMessages: return 60 * 10
            case .privateMessagesInbox: return 60 * 10
            }
        }
        
        static var all: [Refresh] {
            return [.avatar, .bookmarks, .externalStylesheet, .forumList, .loggedInUser, .newPrivateMessages, .privateMessagesInbox]
        }
    }
    
    func shouldRefresh(_ r: Refresh) -> Bool {
        guard let lastRefresh = userDefaults.object(forKey: r.key) as? Date else { return true }
        return Date().timeIntervalSince(lastRefresh) > r.timeBetweenRefreshes
    }
    
    func didRefresh(_ r: Refresh) {
        userDefaults.set(Date(), forKey: r.key)
    }
    
    func suggestedRefreshDate(_ r: Refresh) -> Date {
        guard let lastRefresh = userDefaults.object(forKey: r.key) as? Date else {
            return Date().addingTimeInterval(r.timeBetweenRefreshes)
        }
        let sinceLastRefresh = -lastRefresh.timeIntervalSinceNow
        if sinceLastRefresh > r.timeBetweenRefreshes + 1 {
            return Date()
        }
        return Date().addingTimeInterval(r.timeBetweenRefreshes - sinceLastRefresh)
    }
    
    // MARK: Objective-C bridging
    
    var shouldRefreshLoggedInUser: Bool {
        return shouldRefresh(.loggedInUser)
    }
    func didRefreshLoggedInUser() {
        didRefresh(.loggedInUser)
    }
}

private let forumTimeBetweenRefreshes: TimeInterval = 60 * 15
