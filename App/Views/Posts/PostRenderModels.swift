//  PostRenderModels.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import CoreData
import Foundation

struct PostRenderModel {
    let post: Post
    let enableCustomTitlePostLayout: Bool

    init(_ post: Post, enableCustomTitlePostLayout: Bool = false) {
        self.post = post
        self.enableCustomTitlePostLayout = enableCustomTitlePostLayout
    }
    
    var author: UserRenderModel? {
        post.author.map { UserRenderModel($0, enableCustomTitlePostLayout: enableCustomTitlePostLayout) }
    }

    var htmlContents: String {
        return post.innerHTML ?? ""
    }
    
    var postID: String {
        post.postID
    }
    
    var threadIndex: Int {
        return Int(post.threadIndex)
    }
    
    var postDate: Date? {
        return post.postDate
    }

    var postDateRaw: String {
        if let rawDate = self.post.value(forKey: "postDateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return post.postDate.map { DateFormatter.postDateFormatter.string(from: $0) } ?? ""
    }
    
    var beenSeen: Bool {
        return post.beenSeen
    }
    
    var editable: Bool {
        return post.editable
    }

    var roles: String {
        guard let rolesSet = post.author?.roles as? NSSet else { return "" }
        let cssClasses = rolesSet.allObjects.compactMap { roleObject -> String? in
            guard let role = roleObject as? NSManagedObject,
                  let name = role.value(forKey: "name") as? String else { return nil }
            switch name {
            case "Administrator": return "role-admin"
            case "Moderator": return "role-mod"
            case "Super Moderator": return "role-supermod"
            case "IK": return "role-ik"
            case "Coder": return "role-coder"
            default: return ""
            }
        }
        return cssClasses.joined(separator: " ")
    }
    
    func visibleAvatarURL(showAvatars: Bool) -> URL? {
        guard let author = author else { return nil }
        return author.visibleAvatarURL(showAvatars: showAvatars)
    }

    func hiddenAvatarURL(showAvatars: Bool) -> URL? {
        guard let author = author else { return nil }
        return author.hiddenAvatarURL(showAvatars: showAvatars)
    }

    var customTitleHTML: String? {
        guard enableCustomTitlePostLayout else { return nil }
        return author?.customTitleHTML
    }
    
    // For template compatibility, expose properties using dictionary-like access
    func asDictionary(showAvatars: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "htmlContents": htmlContents,
            "postID": postID,
            "threadIndex": threadIndex,
            "beenSeen": beenSeen,
            "editable": editable,
            "postDateRaw": postDateRaw,
            "roles": roles,
        ]
        
        if let author = author {
            dict["author"] = author.asDictionary(showAvatars: showAvatars)
        }
        
        if let postDate = postDate {
            dict["postDate"] = postDate
        }
        
        let visibleAvatarURL = visibleAvatarURL(showAvatars: showAvatars)
        if let visibleAvatarURL = visibleAvatarURL {
            dict["visibleAvatarURL"] = visibleAvatarURL.absoluteString
        }
        
        let hiddenAvatarURL = hiddenAvatarURL(showAvatars: showAvatars)
        if let hiddenAvatarURL = hiddenAvatarURL {
            dict["hiddenAvatarURL"] = hiddenAvatarURL.absoluteString
        }
        
        if let customTitleHTML = customTitleHTML {
            dict["customTitleHTML"] = customTitleHTML
        }
        
        return dict
    }
}

struct UserRenderModel {
    let user: User
    let enableCustomTitlePostLayout: Bool

    init(_ user: User, enableCustomTitlePostLayout: Bool = false) {
        self.user = user
        self.enableCustomTitlePostLayout = enableCustomTitlePostLayout
    }

    var userID: String {
        user.userID
    }
    
    var username: String? {
        user.username
    }
    
    func visibleAvatarURL(showAvatars: Bool) -> URL? {
        guard showAvatars else { return nil }
        return user.avatarURL
    }

    func hiddenAvatarURL(showAvatars: Bool) -> URL? {
        guard !showAvatars else { return nil }
        return user.avatarURL
    }
    
    var customTitleHTML: String? {
        guard enableCustomTitlePostLayout else { return nil }
        return user.customTitleHTML
    }
    
    var regdate: Date? {
        return user.regdate
    }

    var regdateRaw: String {
        if let rawDate = self.user.value(forKey: "regdateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return user.regdate.map { DateFormatter.regDateFormatter.string(from: $0) } ?? ""
    }
    
    func asDictionary(showAvatars: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "userID": userID,
            "regdateRaw": regdateRaw,
        ]
        
        if let username = username {
            dict["username"] = username
        }
        
        let visibleAvatarURL = visibleAvatarURL(showAvatars: showAvatars)
        if let visibleAvatarURL = visibleAvatarURL {
            dict["visibleAvatarURL"] = visibleAvatarURL.absoluteString
        }

        let hiddenAvatarURL = hiddenAvatarURL(showAvatars: showAvatars)
        if let hiddenAvatarURL = hiddenAvatarURL {
            dict["hiddenAvatarURL"] = hiddenAvatarURL.absoluteString
        }
        
        if let customTitleHTML = customTitleHTML {
            dict["customTitleHTML"] = customTitleHTML
        }
        
        if let regdate = regdate {
            dict["regdate"] = regdate
        }
        
        return dict
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let postDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
    
    static let regDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}