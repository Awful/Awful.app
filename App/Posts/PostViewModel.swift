//  PostViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class PostViewModel: NSObject {
    fileprivate let post: Post
    
    init(post: Post) {
        self.post = post
        super.init()
    }
    
    var HTMLContents: String? {
        guard let innerHTML = post.innerHTML else { return nil }
        let document = HTMLDocument(string: innerHTML)
        RemoveSpoilerStylingAndEvents(document)
        RemoveEmptyEditedByParagraphs(document)
        UseHTML5VimeoPlayer(document)
        HighlightQuotesOfPostsByUserNamed(document, AwfulSettings.shared().username)
        ProcessImgTags(document, !AwfulSettings.shared().showImages)
        if !AwfulSettings.shared().autoplayGIFs {
            StopGifAutoplay(document)
        }
        if post.ignored {
            document.markRevealIgnoredPostLink()
        }
        return document.firstNode(matchingSelector: "body")?.innerHTML
    }
    
    var visibleAvatarURL: URL? {
        return showAvatars ? post.author?.avatarURL as URL? : nil
    }
    
    var hiddenAvatarURL: URL? {
        return showAvatars ? nil : post.author?.avatarURL as URL?
    }
    
    var showAvatars: Bool {
        return AwfulSettings.shared().showAvatars
    }
    
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
    
    var authorIsOP: Bool {
        guard let thisAuthor = post.author, let op = post.thread?.author else { return false }
        return thisAuthor == op
    }
    
    var postDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter()
    }
    
    var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter()
    }
    
    var author: User? {
        return post.author
    }
    
    var beenSeen: Bool {
        return post.beenSeen
    }
    
    var postDate: Date? {
        return post.postDate as Date?
    }
    
    var postID: String {
        return post.postID
    }
}

private extension HTMLDocument {
    func markRevealIgnoredPostLink() {
        guard
            let link = firstNode(matchingSelector: "a[title=\"DON'T DO IT!!\"]"),
            let href = link.objectForKeyedSubscript("href") as? String,
            var components = URLComponents(string: href)
            else { return }
        components.fragment = "awful-ignored"
        guard let replacement = components.url?.absoluteString else { return }
        link.setObject(replacement, forKeyedSubscript: "href")
    }
}
