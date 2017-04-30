//  NSURL-Awful.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

extension URL {
    /// Returns the equivalent awful:// URL, or nil if there is no such thing.
    var awfulURL: URL? {
        if scheme?.caseInsensitiveCompare("awful") == .orderedSame { return self }
        guard verifyHost(self) else { return nil }
        let query = awful_queryDictionary
        
        switch CaseInsensitive(path) {
        case "/showthread.php":
            if let postID = query["postid"] , query["goto"] == "post" || query["action"] == "showpost" {
                return URL(string: "awful://posts/\(postID)")
                
            } else if let fragment = fragment , fragment.hasPrefix("post") && fragment.characters.count > 4 {
                let start = fragment.characters.index(fragment.characters.startIndex, offsetBy: 4)
                let postID = String(fragment.characters[start..<fragment.characters.endIndex])
                return URL(string: "awful://posts/\(postID)")
                
            } else if let threadID = query["threadid"], let pageNumber = query["pagenumber"] {
                guard var components = URLComponents(string: "awful://threads/\(threadID)/pages/\(pageNumber)") else { return nil }
                if let userID = query["userid"] , userID != "0" {
                    components.queryItems = [URLQueryItem(name: "userid", value: userID)]
                }
                return components.url
                
            } else if let threadID = query["threadid"] {
                guard var components = URLComponents(string: "awful://threads/\(threadID)/pages/1") else { return nil }
                if let userID = query["userid"] , userID != "0" {
                    components.queryItems = [URLQueryItem(name: "userid", value: userID)]
                }
                return components.url
            } else {
                return nil
            }
            
        case "/forumdisplay.php":
            if let forumID = query["forumid"] {
                return URL(string: "awful://forums/\(forumID)")
            } else {
                return nil
            }
            
        case "/member.php" where query["action"] == "getinfo":
            if let userID = query["userid"] {
                return URL(string: "awful://users/\(userID)")
            } else {
                return nil
            }
            
        case "/banlist.php":
            if let userID = query["userid"] {
                return URL(string: "awful://banlist/\(userID)")
            } else {
                return URL(string: "awful://banlist")
            }
            
        default:
            return nil
        }
    }
}

private func verifyHost(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    switch CaseInsensitive(host) {
    case "forums.somethingawful.com", "archives.somethingawful.com", ForumsClient.shared.baseURL?.host ?? "forums.somethingawful.com":
        return true
    default:
        return false
    }
}
