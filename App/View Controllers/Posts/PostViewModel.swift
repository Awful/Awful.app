//  PostViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader

struct PostRenderModel: StencilContextConvertible {
    let context: [String: Any]

    init(_ post: Post) {
        var roles: String {
            guard let author = post.author else { return "" }
            var roles = author.authorClasses ?? ""
            if post.thread?.author == author {
                roles += " op"
            }
            return roles
        }
        var accessibilityRoles: String {
            let spokenRoles = [
                "ik": "internet knight",
                "op": "original poster",
                ]
            return roles
                .components(separatedBy: .whitespacesAndNewlines)
                .map { spokenRoles[$0] ?? $0 }
                .joined(separator: "; ")
        }
        var forumID: String {
            return post.thread?.forum?.forumID ?? ""
        }
        var showRegdate: Bool {
            if let tweaks = ForumTweaks(forumID: forumID) {
                return tweaks.showRegdate
            }
            return true
        }
        var showAvatars: Bool {
            return UserDefaults.standard.showAuthorAvatars
        }
        var hiddenAvatarURL: URL? {
            return showAvatars ? nil : post.author?.avatarURL
        }
        var htmlContents: String {
            return massageHTML(post.innerHTML ?? "", isIgnored: post.ignored, forumID: forumID)
        }
        var visibleAvatarURL: URL? {
            return showAvatars ? post.author?.avatarURL : nil
        }
        var customTitleHTML: String {
            let html = post.author?.customTitleHTML
            return html ?? ""
        }

        context = [
            "accessibilityRoles": accessibilityRoles,
            "author": [
                "regdate": post.author?.regdate as Any,
                "userID": post.author?.userID as Any,
                "username": post.author?.username as Any],
            "beenSeen": post.beenSeen,
            "customTitleHTML": (enableCustomTitlePostLayout ? post.author?.customTitleHTML : nil) as Any,
            "hiddenAvatarURL": hiddenAvatarURL as Any,
            "htmlContents": htmlContents,
            "postDate": post.postDate as Any,
            "postID": post.postID,
            "roles": roles,
            "showAvatars": showAvatars,
            "showRegdate": showRegdate,
            "visibleAvatarURL": visibleAvatarURL as Any]
    }
    
    init(author: User, isOP: Bool, postDate: Date, postHTML: String) {
        context = [
            "author": [
                "regdate": author.regdate as Any,
                "userID": author.userID,
                "username": author.username as Any],
            "beenSeen": false,
            "hiddenAvatarURL": (showAvatars ? author.avatarURL : nil) as Any,
            "customTitleHTML": (enableCustomTitlePostLayout ? author.customTitleHTML : nil) as Any,
            "htmlContents": massageHTML(postHTML, isIgnored: false, forumID: ""),
            "postDate": postDate,
            "postID": "fake",
            "roles": (isOP ? "op " : "") + (author.authorClasses ?? ""),
            "showAvatars": showAvatars,
            "visibleAvatarURL": (showAvatars ? author.avatarURL : nil) as Any]
    }
}

private func massageHTML(_ html: String, isIgnored: Bool, forumID: String) -> String {
    let document = HTMLDocument(string: html)
    document.removeSpoilerStylingAndEvents()
    document.removeEmptyEditedByParagraphs()
    document.addAttributeToTweetLinks()
    document.useHTML5VimeoPlayer()
    if let username = UserDefaults.standard.loggedInUsername {
        document.identifyQuotesCitingUser(named: username, shouldHighlight: true)
        document.identifyMentionsOfUser(named: username, shouldHighlight: true)
    }
    document.processImgTags(shouldLinkifyNonSmilies: !UserDefaults.standard.showImages)
    if !UserDefaults.standard.automaticallyPlayGIFs {
        document.stopGIFAutoplay()
    }
    if isIgnored {
        document.markRevealIgnoredPostLink()
    }
    if (ForumTweaks(forumID: forumID)?.magicCake) == true {
        document.addMagicCakeCSS()
    }
    document.embedVideos()
    return document.bodyElement?.innerHTML ?? ""
}

private var showAvatars: Bool {
    return UserDefaults.standard.showAuthorAvatars
}

private var enableCustomTitlePostLayout: Bool {
    switch UIDevice.current.userInterfaceIdiom {
    case .mac, .pad:
        return UserDefaults.standard.enableCustomTitlePostLayout
    default:
        return false
    }
}

private extension HTMLDocument {
    func markRevealIgnoredPostLink() {
        guard
            let link = firstNode(matchingSelector: "a[title=\"DON'T DO IT!!\"]"),
            let href = link["href"],
            var components = URLComponents(string: href)
            else { return }
        components.fragment = "awful-ignored"
        guard let replacement = components.url?.absoluteString else { return }
        link["href"] = replacement
    }
}
