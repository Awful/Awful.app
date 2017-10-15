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
        
        switch CaseInsensitive(path) {
        case "/showthread.php":
            if
                let postID = valueForFirstQueryItem(named: "postid"),
                valueForFirstQueryItem(named: "goto") == "post"
                    || valueForFirstQueryItem(named: "action") == "showpost"
            {
                return URL(string: "awful://posts/\(postID)")
                
            }
            else if
                let fragment = fragment,
                fragment.hasPrefix("post"),
                fragment.count > 4
            {
                let start = fragment.index(fragment.startIndex, offsetBy: 4)
                let postID = String(fragment[start...])
                return URL(string: "awful://posts/\(postID)")
                
            }
            else if
                let threadID = valueForFirstQueryItem(named: "threadid"),
                let pageNumber = valueForFirstQueryItem(named: "pagenumber")
            {
                guard var components = URLComponents(string: "awful://threads/\(threadID)/pages/\(pageNumber)") else { return nil }
                if let userID = valueForFirstQueryItem(named: "userid"), userID != "0" {
                    components.queryItems = [URLQueryItem(name: "userid", value: userID)]
                }
                return components.url
                
            }
            else if let threadID = valueForFirstQueryItem(named: "threadid") {
                guard var components = URLComponents(string: "awful://threads/\(threadID)/pages/1") else { return nil }
                if let userID = valueForFirstQueryItem("userid"), userID != "0" {
                    components.queryItems = [URLQueryItem(name: "userid", value: userID)]
                }
                return components.url
            }
            else {
                return nil
            }
            
        case "/forumdisplay.php":
            if let forumID = valueForFirstQueryItem(named: "forumid") {
                return URL(string: "awful://forums/\(forumID)")
            }
            else {
                return nil
            }
            
        case "/member.php" where valueForFirstQueryItem(named: "action") == "getinfo":
            if let userID = valueForFirstQueryItem(named: "userid") {
                return URL(string: "awful://users/\(userID)")
            }
            else {
                return nil
            }
            
        case "/banlist.php":
            if let userID = valueForFirstQueryItem(named: "userid") {
                return URL(string: "awful://banlist/\(userID)")
            }
            else {
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
    case "forums.somethingawful.com",
         "archives.somethingawful.com",
         ForumsClient.shared.baseURL?.host ?? "forums.somethingawful.com":
        return true
    
    default:
        return false
    }
}
