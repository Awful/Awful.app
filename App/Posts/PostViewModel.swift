//  PostViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class PostViewModel: NSObject {
    private let post: Post
    
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
        HighlightQuotesOfPostsByUserNamed(document, AwfulSettings.sharedSettings().username)
        ProcessImgTags(document, !AwfulSettings.sharedSettings().showImages)
        if !AwfulSettings.sharedSettings().autoplayGIFs {
            StopGifAutoplay(document)
        }
        if post.ignored {
            document.markRevealIgnoredPostLink()
        }
        return document.firstNodeMatchingSelector("body")?.innerHTML
    }
    
    var visibleAvatarURL: NSURL? {
        return showAvatars ? post.author?.avatarURL : nil
    }
    
    var hiddenAvatarURL: NSURL? {
        return showAvatars ? nil : post.author?.avatarURL
    }
    
    var showAvatars: Bool {
        return AwfulSettings.sharedSettings().showAvatars
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
            "op": "oritinal poster",
            ]
        return roles
            .componentsSeparatedByCharactersInSet(.whitespaceAndNewlineCharacterSet())
            .map { spokenRoles[$0] ?? $0 }
            .joinWithSeparator("; ")
    }
    
    var authorIsOP: Bool {
        guard let thisAuthor = post.author, op = post.thread?.author else { return false }
        return thisAuthor == op
    }
    
    var postDateFormat: NSDateFormatter {
        return NSDateFormatter.postDateFormatter()
    }
    
    var regDateFormat: NSDateFormatter {
        return NSDateFormatter.regDateFormatter()
    }
    
    var author: User? {
        return post.author
    }
    
    var beenSeen: Bool {
        return post.beenSeen
    }
    
    var postDate: NSDate? {
        return post.postDate
    }
    
    var postID: String {
        return post.postID
    }
}

private extension HTMLDocument {
    func markRevealIgnoredPostLink() {
        guard let
            link = firstNodeMatchingSelector("a[title=\"DON'T DO IT!!\"]"),
            href = link.objectForKeyedSubscript("href") as? String,
            components = NSURLComponents(string: href)
            else { return }
        components.fragment = "awful-ignored"
        guard let replacement = components.URL?.absoluteString else { return }
        link.setObject(replacement, forKeyedSubscript: "href")
    }
}
