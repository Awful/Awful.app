//  NSURL-Awful.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

extension NSURL {
    /// Returns the equivalent awful:// URL, or nil if there is no such thing.
    var awfulURL: NSURL? {
        if scheme.caseInsensitiveCompare("awful") == .OrderedSame { return self }
        guard verifyHost(self) else { return nil }
        guard let path = path else { return nil }
        let query = awful_queryDictionary
        
        switch CaseInsensitive(path) {
        case "/showthread.php":
            if let postID = query["postID"] where query["goto"] == "post" || query["action"] == "showpost" {
                return NSURL(string: "awful://posts/\(postID)")
                
            } else if let fragment = fragment where fragment.hasPrefix("post") && fragment.characters.count > 4 {
                let start = fragment.characters.startIndex.advancedBy(4)
                let postID = String(fragment.characters[start..<fragment.characters.endIndex])
                return NSURL(string: "awful://posts/\(postID)")
                
            } else if let threadID = query["threadID"], pageNumber = query["pagenumber"] {
                guard let components = NSURLComponents(string: "awful://threads/\(threadID)/pages/\(pageNumber)") else { return nil }
                if let userID = query["userid"] where userID != "0" {
                    components.queryItems = [NSURLQueryItem(name: "userid", value: userID)]
                }
                return components.URL
                
            } else if let threadID = query["threadID"] {
                guard let components = NSURLComponents(string: "awful://threads/\(threadID)/pages/1") else { return nil }
                if let userID = query["userid"] where userID != "0" {
                    components.queryItems = [NSURLQueryItem(name: "userid", value: userID)]
                }
                return components.URL
            } else {
                return nil
            }
            
        case "/forumdisplay.php":
            if let forumID = query["forumID"] {
                return NSURL(string: "awful://forums/\(forumID)")
            } else {
                return nil
            }
            
        case "/member.php" where query["action"] == "getinfo":
            if let userID = query["userid"] {
                return NSURL(string: "awful://users/\(userID)")
            } else {
                return nil
            }
            
        case "/banlist.php":
            if let userID = query["userid"] {
                return NSURL(string: "awful://banlist/\(userID)")
            } else {
                return NSURL(string: "awful://banlist")
            }
            
        default:
            return nil
        }
    }
}

private func verifyHost(URL: NSURL) -> Bool {
    guard let host = URL.host else { return false }
    switch CaseInsensitive(host) {
    case "forums.somethingawful.com", "archives.somethingawful.com", AwfulForumsClient.sharedClient().baseURL.host:
        return true
    default:
        return false
    }
}
