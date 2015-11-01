//  Handoff.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Awful NSUserActivity.userInfo keys, wrapped in a class for Objective-C exposure.
@objc final class Handoff: NSObject {
    /// An NSNumber included in all Awful NSUserActivity.userInfo dictionaries for future-proofing.
    class var InfoVersionKey: String { return "version" }
    
    /// Browsing a page of posts. On the Forums, this is `showthread.php`.
    class var ActivityTypeBrowsingPosts: String { return "com.awfulapp.Awful.activity.browsing-posts" }
    /// An NSString of the thread's ID.
    class var InfoThreadIDKey: String { return "threadID" }
    /// An NSNumber of the page of the thread.
    class var InfoPageKey: String { return "page" }
    /// An NSString of the currently-visible post's ID.
    class var InfoPostIDKey: String { return "postID" }
    /// An NSString of the author's user ID. Only present when filtering the thread by posts written by this author.
    class var InfoFilteredThreadUserIDKey: String { return "filteredUserID" }
    
    /// Browsing a forum or bookmarked threads. On the Forums, this is `forumdisplay.php` or `bookmarkthreads.php`.
    class var ActivityTypeListingThreads: String { return "com.awfulapp.Awful.activity.listing-threads" }
    /// An NSString of the forum's ID. Only present when browing a forum.
    class var InfoForumIDKey: String { return "forumID" }
    /// An NSNumber `YES`. Only present when listing bookmarked threads.
    class var InfoBookmarksKey: String { return "bookmarks" }
    
    /// Reading a private message. On the Forums, this is `private.php?action=show`.
    class var ActivityTypeReadingMessage: String { return "com.awfulapp.Awful.activity.reading-message" }
    /// An NSString of the message's ID.
    class var InfoMessageIDKey: String { return "messageID" }
}

extension NSUserActivity {
    /// An awful:// URL locating the user activity, or nil if no such URL exists.
    var awfulURL: NSURL? {
        if let userInfo = userInfo {
            switch activityType {
            case Handoff.ActivityTypeBrowsingPosts where userInfo[Handoff.InfoFilteredThreadUserIDKey] != nil:
                var URL = "awful://threads/\(userInfo[Handoff.InfoThreadIDKey]!)"
                if let page: AnyObject = userInfo[Handoff.InfoPageKey] {
                    URL += "/pages/\(page)"
                }
                URL += "?userid=\(userInfo[Handoff.InfoFilteredThreadUserIDKey]!)"
                if let postID: AnyObject = userInfo[Handoff.InfoPostIDKey] {
                    URL += "#post=\(postID)"
                }
                return NSURL(string: URL)
            case Handoff.ActivityTypeBrowsingPosts where userInfo[Handoff.InfoPostIDKey] != nil:
                return NSURL(string: "awful://posts/\(userInfo[Handoff.InfoPostIDKey]!)")
            case Handoff.ActivityTypeBrowsingPosts:
                var URL = "awful://threads/\(userInfo[Handoff.InfoThreadIDKey]!)"
                if let page: AnyObject = userInfo[Handoff.InfoPageKey] {
                    URL += "/pages/\(page)"
                }
                return NSURL(string: URL)
            case Handoff.ActivityTypeListingThreads:
                return NSURL(string: "awful://forums/\(userInfo[Handoff.InfoForumIDKey]!)")
            case Handoff.ActivityTypeReadingMessage:
                return NSURL(string: "awful://messages/\(userInfo[Handoff.InfoMessageIDKey]!)")
            default:
                break
            }
        }
        return nil
    }
}

extension UIDevice {
    /// Whether the device is capable of Handoff. Returns true even if the user has otherwise disabled Handoff.
    var isHandoffCapable: Bool {
        // Handoff starts at iPhone 5, iPod Touch 5G, iPad 4G, iPad Mini 1: http://support.apple.com/en-us/HT6555
        // Models are listed at http://theiphonewiki.com/wiki/Models
        // Let's assume all future models also support Handoff.
        let scanner = NSScanner(string: modelIdentifier())
        var major: Int = Int.min
        if scanner.scanString("iPad", intoString: nil) && scanner.scanInteger(&major) {
            return major >= 2
        } else if scanner.scanString("iPhone", intoString: nil) && scanner.scanInteger(&major) {
            return major >= 5
        } else if scanner.scanString("iPod", intoString: nil) && scanner.scanInteger(&major) {
            return major >= 5
        } else {
            return false
        }
    }
}

private func modelIdentifier() -> String {
    var size: Int = 0
    if sysctlbyname("hw.machine", nil, &size, nil, 0) != 0 {
        NSLog("%@ failed to get buffer size", __FUNCTION__)
        return ""
    }
    
    let bufferSize = Int(size) + 1
    let buffer = UnsafeMutablePointer<CChar>.alloc(bufferSize)
    if sysctlbyname("hw.machine", buffer, &size, nil, 0) != 0 {
        NSLog("%@ failed to get model identifier", __FUNCTION__)
        buffer.dealloc(bufferSize)
        return ""
    }
    
    buffer[Int(size)] = 0
    let identifier = String.fromCString(buffer)!
    
    buffer.dealloc(bufferSize)
    return identifier
}
