//  PostRenderModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import HTMLReader
import UIKit

struct PostRenderModel: StencilContextConvertible {
    let context: [String: Any]

    /// How many post content images a page loads immediately before the rest load lazily.
    static let eagerImagesPerPage = HTMLDocument.immediatelyLoadedImageCount

    init(_ post: Post) {
        var eagerImageAllowance = Self.eagerImagesPerPage
        self.init(post, eagerImageAllowance: &eagerImageAllowance)
    }

    /// - Parameter eagerImageAllowance: How many more of the page's post content images may load immediately rather than lazily. Share one across all the posts on a page.
    init(_ post: Post, eagerImageAllowance: inout Int) {
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
            if let tweaks = ForumTweaks(ForumID(forumID)) {
                return tweaks.showRegdate
            }
            return true
        }
        var showAvatars: Bool { Awful.showAvatars }
        var hiddenAvatarURL: URL? {
            return showAvatars ? nil : post.author?.avatarURL
        }
        let htmlContents = massageHTML(post.innerHTML ?? "", isIgnored: post.ignored, forumID: forumID, eagerImageAllowance: &eagerImageAllowance)
        var visibleAvatarURL: URL? {
            return showAvatars ? post.author?.avatarURL : nil
        }
        var customTitleHTML: String {
            let html = post.author?.customTitleHTML
            return html ?? ""
        }
        var postDateRaw: String {
            return post.postDateRaw ?? ""
        }

        context = [
            "accessibilityRoles": accessibilityRoles,
            "author": [
                "regdate": post.author?.regdate as Any,
                "regdateRaw": post.author?.regdateRaw as Any,
                "userID": post.author?.userID as Any,
                "username": post.author?.username as Any],
            "beenSeen": post.beenSeen,
            "customTitleHTML": (enableCustomTitlePostLayout ? post.author?.customTitleHTML : nil) as Any,
            "hiddenAvatarURL": hiddenAvatarURL as Any,
            "hideMetadataForReader": hidePostMetadataForReader,
            "htmlContents": htmlContents,
            "postDate": post.postDate as Any,
            "postDateRaw": postDateRaw as String,
            "postID": post.postID,
            "roles": roles,
            "showAvatars": showAvatars,
            "showRegdate": showRegdate,
            "visibleAvatarURL": visibleAvatarURL as Any]
    }

    init(author: User, isOP: Bool, postDate: String, postHTML: String) {
        var eagerImageAllowance = Self.eagerImagesPerPage
        context = [
            "author": [
                "regdate": author.regdate as Any,
                "userID": author.userID,
                "username": author.username as Any],
            "beenSeen": false,
            "hiddenAvatarURL": (showAvatars ? author.avatarURL : nil) as Any,
            "hideMetadataForReader": hidePostMetadataForReader,
            "customTitleHTML": (enableCustomTitlePostLayout ? author.customTitleHTML : nil) as Any,
            "htmlContents": massageHTML(postHTML, isIgnored: false, forumID: "", eagerImageAllowance: &eagerImageAllowance),
            "postDate": postDate,
            "postDateRaw": "",
            "postID": "fake",
            "roles": (isOP ? "op " : "") + (author.authorClasses ?? ""),
            "showAvatars": showAvatars,
            "visibleAvatarURL": (showAvatars ? author.avatarURL : nil) as Any]
    }
}

private func massageHTML(_ html: String, isIgnored: Bool, forumID: String, eagerImageAllowance: inout Int) -> String {
    let document = HTMLDocument(string: html)
    document.removeSpoilerStylingAndEvents()
    document.removeEmptyEditedByParagraphs()
    document.addAttributeToBlueskyLinks()
    document.addAttributeToTweetLinks()
    let embedVideos = UserDefaults.standard.defaultingValue(for: Settings.embedVideos)
    if embedVideos {
        document.useHTML5VimeoPlayer()
    }
    if let username = UserDefaults.standard.value(for: Settings.username) {
        document.identifyQuotesCitingUser(named: username, shouldHighlight: true)
        document.identifyMentionsOfUser(named: username, shouldHighlight: true)
    }
    document.processImgTags(shouldLinkifyNonSmilies: !UserDefaults.standard.defaultingValue(for: Settings.loadImages), eagerImageAllowance: &eagerImageAllowance)
    if !UserDefaults.standard.defaultingValue(for: Settings.autoplayGIFs) {
        document.stopGIFAutoplay()
    }
    if isIgnored {
        document.markRevealIgnoredPostLink()
    }
    if (ForumTweaks(ForumID(forumID))?.magicCake) == true {
        document.addMagicCakeCSS()
    }
    if embedVideos {
        document.embedVideos()
    } else {
        document.linkifyResidualVideoEmbeds()
    }
    return document.bodyElement?.innerHTML ?? ""
}

private var showAvatars: Bool {
    UserDefaults.standard.defaultingValue(for: Settings.showAvatars)
}

private var hidePostMetadataForReader: Bool {
    UserDefaults.standard.defaultingValue(for: Settings.hidePostMetadataForReader)
}

private var enableCustomTitlePostLayout: Bool {
    switch UIDevice.current.userInterfaceIdiom {
    case .mac, .pad:
        return UserDefaults.standard.defaultingValue(for: Settings.enableCustomTitlePostLayout)
    default:
        return false
    }
}

private extension HTMLDocument {
    func markRevealIgnoredPostLink() {
        guard
            let link = firstNode(matchingParsedSelector: .cached("a[title=\"DON'T DO IT!!\"]")),
            let href = link["href"],
            var components = URLComponents(string: href)
            else { return }
        components.fragment = "awful-ignored"
        guard let replacement = components.url?.absoluteString else { return }
        link["href"] = replacement
    }
}
