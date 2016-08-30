//  RefreshMinder.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class RefreshMinder: NSObject {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    static let sharedMinder = RefreshMinder(userDefaults: UserDefaults.standard)
    
    func shouldRefreshForum(forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastRefresh else { return true }
        return NSDate().timeIntervalSince(lastRefresh as Date) > forumTimeBetweenRefreshes
    }
    
    func didRefreshForum(forum: Forum) {
        forum.lastRefresh = NSDate()
    }
    
    func shouldRefreshFilteredForum(forum: Forum) -> Bool {
        guard let lastRefresh = forum.lastFilteredRefresh else { return true }
        return NSDate().timeIntervalSince(lastRefresh as Date) > forumTimeBetweenRefreshes
    }
    
    func didRefreshFilteredForum(forum: Forum) {
        forum.lastFilteredRefresh = NSDate()
    }
    
    func forgetForum(forum: Forum) {
        forum.lastRefresh = nil
        forum.lastFilteredRefresh = nil
    }
    
    func forgetEverything() {
        Refresh.all.forEach { userDefaults.removeObjectForKey($0.key) }
    }
    
    enum Refresh {
        case Avatar
        case Bookmarks
        case ExternalStylesheet
        case ForumList
        case LoggedInUser
        case NewPrivateMessages
        case PrivateMessagesInbox
        
        private var key: String {
            switch self {
            case .Avatar: return "LastLoggedInUserAvatarRefreshDate"
            case .Bookmarks: return "com.awfulapp.Awful.LastBookmarksRefreshDate"
            case .ExternalStylesheet: return "LastExternalStylesheetRefreshDate"
            case .ForumList: return "com.awfulapp.Awful.LastForumRefreshDate"
            case .LoggedInUser: return "LastLoggedInUserRefreshDate"
            case .NewPrivateMessages: return "com.awfulapp.Awful.LastMessageCheckDate"
            case .PrivateMessagesInbox: return "LastPrivateMessageInboxRefreshDate"
            }
        }
        
        private var timeBetweenRefreshes: TimeInterval {
            switch self {
            case .Avatar: return 60 * 10
            case .Bookmarks: return 60 * 10
            case .ExternalStylesheet: return 60 * 60
            case .ForumList: return 60 * 60 * 6
            case .LoggedInUser: return 60 * 5
            case .NewPrivateMessages: return 60 * 10
            case .PrivateMessagesInbox: return 60 * 10
            }
        }
        
        static var all: [Refresh] {
            return [.Avatar, .Bookmarks, .ExternalStylesheet, .ForumList, .LoggedInUser, .NewPrivateMessages, .PrivateMessagesInbox]
        }
    }
    
    func shouldRefresh(r: Refresh) -> Bool {
        guard let lastRefresh = userDefaults.objectForKey(r.key) as? NSDate else { return true }
        return NSDate().timeIntervalSinceDate(lastRefresh) > r.timeBetweenRefreshes
    }
    
    func didRefresh(r: Refresh) {
        userDefaults.setObject(NSDate(), forKey: r.key)
    }
    
    func suggestedRefreshDate(r: Refresh) -> NSDate {
        guard let lastRefresh = userDefaults.objectForKey(r.key) as? NSDate else {
            return NSDate().dateByAddingTimeInterval(r.timeBetweenRefreshes)
        }
        let sinceLastRefresh = -lastRefresh.timeIntervalSinceNow
        if sinceLastRefresh > r.timeBetweenRefreshes + 1 {
            return NSDate()
        }
        return NSDate().dateByAddingTimeInterval(r.timeBetweenRefreshes - sinceLastRefresh)
    }
    
    // MARK: Objective-C bridging
    
    var shouldRefreshLoggedInUser: Bool {
        return shouldRefresh(r: .LoggedInUser)
    }
    func didRefreshLoggedInUser() {
        didRefresh(r: .LoggedInUser)
    }
}

private let forumTimeBetweenRefreshes: TimeInterval = 60 * 15
