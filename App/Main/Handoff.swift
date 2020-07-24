//  Handoff.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

private let Log = Logger.get()

extension NSUserActivity {

    /// The getter attempts to turn the user activity into a route, returning `nil` if no route exists that matches the activity. The setter sets values for the route's `userInfo` keys and sets the `webpageURL`.
    var route: AwfulRoute? {
        get {
            guard let userInfo = userInfo else { return nil }
            switch activityType {

            case Handoff.ActivityType.browsingPosts:
                guard let threadID = userInfo[Keys.threadID] as? String else {
                    Log.e("cannot continue 'browsing posts' Handoff activity without a thread ID")
                    return nil
                }

                let pageNumber = userInfo[Keys.page] as? Int
                let page = pageNumber.map { ThreadPage.specific($0) } ?? .nextUnread

                if let userID = userInfo[Keys.filteredThreadUserID] as? String {
                    return .threadPageSingleUser(threadID: threadID, userID: userID, page: page, .noseen)
                } else {
                    return .threadPage(threadID: threadID, page: page, .noseen)
                }

            case Handoff.ActivityType.listingThreads:
                if userInfo[Keys.bookmarks] != nil {
                    return .bookmarks
                } else if let forumID = userInfo[Keys.forumID] as? String {
                    return .forum(id: forumID)
                } else {
                    Log.e("cannot continue 'listing threads' Handoff activity without either bookmarks or a forum ID")
                    return nil
                }

            case Handoff.ActivityType.readingMessage:
                guard let messageID = userInfo[Keys.messageID] as? String else {
                    Log.e("cannot continue 'reading message' Handoff activity without a message ID")
                    return nil
                }
                return .message(id: messageID)

            default:
                return nil
            }
        }

        set {
            guard let route = newValue else { return }

            switch route {
            case .bookmarks:
                addUserInfoEntries(from: [Keys.bookmarks: true])

            case let .forum(id: forumID):
                addUserInfoEntries(from: [Keys.forumID: forumID])

            case let .message(id: messageID):
                addUserInfoEntries(from: [Keys.messageID: messageID])

            case let .threadPage(threadID: threadID, page: .specific(page), _):
                addUserInfoEntries(from: [Keys.threadID: threadID, Keys.page: page])

            case let .threadPageSingleUser(threadID: threadID, userID: userID, page: .specific(page), _):
                addUserInfoEntries(from: [
                    Keys.threadID: threadID,
                    Keys.filteredThreadUserID: userID,
                    Keys.page: page])

            case .forumList, .lepersColony, .messagesList, .post, .profile, .rapSheet, .settings, .threadPage, .threadPageSingleUser:
                Log.e("setting a Handoff route \(route) has no effect!")
                return
            }

            addUserInfoEntries(from: [Keys.version: handoffUserInfoVersion])
            webpageURL = route.httpURL
        }
    }
}

/// Constants for Handoff support.
enum Handoff {

    /// Supported `NSUserActivity` activity types.
    enum ActivityType {

        /// Browsing a page of posts. On the Forums, this is `showthread.php`.
        static let browsingPosts = "com.awfulapp.Awful.activity.browsing-posts"

        /// Browsing a forum or bookmarked threads. On the Forums, this is `forumdisplay.php` or `bookmarkthreads.php`.
        static let listingThreads = "com.awfulapp.Awful.activity.listing-threads"

        /// Reading a private message. On the Forums, this is `private.php?action=show`.
        static let readingMessage = "com.awfulapp.Awful.activity.reading-message"
    }
}

private enum Keys {

    /// `true`. Only present when listing bookmarked threads.
    static let bookmarks = "bookmarks"

    /// A `String` of the author's user ID. Only present when filtering the thread by posts written by this author.
    static let filteredThreadUserID = "filteredUserID"

    /// A `String` of the forum's ID. Only present when browing a forum.
    static let forumID = "forumID"

    /// A `String` of the message's ID.
    static let messageID = "messageID"

    /// An `Int` of the page of the thread.
    static let page = "page"

    /// A `String` of the currently-visible post's ID.
    static let postID = "postID"

    /// A `String` of the thread's ID.
    static let threadID = "threadID"

    /// An `Int` included in all Awful `NSUserActivity.userInfo` dictionaries for future-proofing.
    static let version = "version"
}

/// Increment this number if you make an incompatible change to the user info stored for a Handoff activity.
private let handoffUserInfoVersion = 1
