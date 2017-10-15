//  PostViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader

final class PostViewModel: NSObject {
    fileprivate let post: Post
    
    init(post: Post) {
        self.post = post
        super.init()
    }
    
    @objc var HTMLContents: String? {
        guard let innerHTML = post.innerHTML else { return nil }
        let document = HTMLDocument(string: innerHTML)
        document.removeSpoilerStylingAndEvents()
        document.removeEmptyEditedByParagraphs()
        document.useHTML5VimeoPlayer()
        document.highlightQuotesOfPosts(byUserNamed: AwfulSettings.shared().username)
        document.processImgTags(shouldLinkifyNonSmilies: !AwfulSettings.shared().showImages)
        if !AwfulSettings.shared().autoplayGIFs {
            document.stopGIFAutoplay()
        }
        if post.ignored {
            document.markRevealIgnoredPostLink()
        }
        return document.firstNode(matchingSelector: "body")?.innerHTML
    }
    
    @objc var visibleAvatarURL: URL? {
        return showAvatars ? post.author?.avatarURL as URL? : nil
    }
    
    @objc var hiddenAvatarURL: URL? {
        return showAvatars ? nil : post.author?.avatarURL as URL?
    }
    
    @objc var showAvatars: Bool {
        return AwfulSettings.shared().showAvatars
    }
    
    @objc var roles: String {
        guard let author = post.author else { return "" }
        var roles = author.authorClasses ?? ""
        if post.thread?.author == author {
            roles += " op"
        }
        return roles
    }
    
    @objc var accessibilityRoles: String {
        let spokenRoles = [
            "ik": "internet knight",
            "op": "original poster",
            ]
        return roles
            .components(separatedBy: .whitespacesAndNewlines)
            .map { spokenRoles[$0] ?? $0 }
            .joined(separator: "; ")
    }
    
    @objc var authorIsOP: Bool {
        guard let thisAuthor = post.author, let op = post.thread?.author else { return false }
        return thisAuthor == op
    }
    
    @objc var postDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter
    }
    
    @objc var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter
    }
    
    @objc var author: User? {
        return post.author
    }
    
    @objc var beenSeen: Bool {
        return post.beenSeen
    }
    
    @objc var postDate: Date? {
        return post.postDate as Date?
    }
    
    @objc var postID: String {
        return post.postID
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
