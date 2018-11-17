//  HTMLRenderingHelpers.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

extension HTMLDocument {
    
    /// Finds links that appear to be to tweets and adds a `data-tweet-id` attribute to those links.
    func addAttributeToTweetLinks() {
        for a in nodes(matchingSelector: "a[href *= 'twitter.com']") {
            guard
                let href = a["href"],
                let url = URL(string: href),
                let host = url.host,
                host.lowercased().hasSuffix("twitter.com")
                else { continue }
            
            let pathComponents = url.pathComponents
            guard
                pathComponents.count >= 4,
                pathComponents[2].lowercased().hasPrefix("status")
                else { continue }
            
            let id = pathComponents[3]
            guard id.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains) else { continue }
            
            a["data-tweet-id"] = id
        }
    }
    
    /**
     Modifies the document in place, wrapping any occurrences of `username` in a post body within a `<span class="mention">` element. Additionally, if `isHighlighted` is `true`, the class `highlight` is added to the wrapping span elements.
     */
    func identifyMentionsOfUser(named username: String, shouldHighlight isHighlighted: Bool) {
        guard let body = bodyElement else { return }
        
        let escapedUsername = NSRegularExpression.escapedPattern(for: username)
        let regex = try! NSRegularExpression(
            // Since usernames can contain what a regex thinks of as non-word characters, searching on word boundaries (`\b`) doesn't quite cut it for us. We also want to consider the start/end of the string, and beginning/ending on whitespace.
            pattern: "(?:\\A|\\b|\\s)"
                + "(\(escapedUsername))" // Capture just the username so we don't wrap any surrounding whitespace.
                + "(?:\\b|\\s|\\z)",
            options: .caseInsensitive)
        
        let classAttribute = "mention" + (isHighlighted ? " highlight" : "")
        
        var matches: [(HTMLTextNode, [NSTextCheckingResult])] = []
        for node in body.treeEnumerator() {
            guard let textNode = node as? HTMLTextNode else {
                continue
            }
            
            let results = regex.matches(in: textNode.data, range: NSRange(textNode.data.startIndex..., in: textNode.data))
            if !results.isEmpty {
                matches.append((textNode, results))
            }
        }
        
        matchLoop:
        for (textNode, results) in matches {
            
            // We'll move backwards through the text node, splitting it as we go.
            var remainder = textNode
            
            for result in results.reversed() {
                guard let resultRange = Range(result.range(at: 1), in: remainder.data) else {
                    continue
                }
                
                let mention = HTMLElement(tagName: "span", attributes: ["class": classAttribute])
                
                switch remainder.split(resultRange) {
                case let .entireNode(mentionText),
                     let .anchoredAtBeginning(match: mentionText, remainder: _):
                    
                    mentionText.wrap(in: mention)
                    continue matchLoop
                    
                case let .anchoredAtEnd(remainder: _remainder, match: mentionText),
                     let .middle(beginning: _remainder, match: mentionText, end: _):
                    
                    mentionText.wrap(in: mention)
                    remainder = _remainder
                }
            }
        }
    }
    
    /**
     Modifies the document in place, adding the `mention` class to the header above a quote if it says "username posted:". If `shouldHighlight` is `true`, also adds the `highlight` class.
     */
    func identifyQuotesCitingUser(named username: String, shouldHighlight isHighlighted: Bool) {
        let loggedInUserPosted = "\(username) posted:"
        for h4 in nodes(matchingSelector: ".bbc-block h4") where h4.textContent == loggedInUserPosted {
            var block = h4.parentElement
            while let next = block, !next.hasClass("bbc-block") {
                block = next.parentElement
            }
            block?.toggleClass("mention")
            
            if isHighlighted {
                block?.toggleClass("highlight")
            }
        }
    }
    
    /**
     Modifies the document in place:
     
     - Turns all non-smiley `<img src=>` elements into `<a data-awful='image'>src</a>` elements (if linkifyNonSmiles == true).
     - Adds .awful-smile to smilie elements.
     - Rewrites URLs for some external image hosts that have changed domains and/or URL schemes.
     */
    func processImgTags(shouldLinkifyNonSmilies: Bool) {
        for img in nodes(matchingSelector: "img") {
            guard
                let src = img["src"],
                let url = URL(string: src)
                else { continue }
            
            let isSmilie = isSmilieURL(url)
            
            if isSmilie {
                img.toggleClass("awful-smile")
            } else if let postimageURL = fixPostimageURL(url) {
                img["src"] = postimageURL.absoluteString
            } else if let waffleURL = randomwaffleURLForWaffleimagesURL(url) {
                img["src"] = waffleURL.absoluteString
            }
            
            if shouldLinkifyNonSmilies, !isSmilie {
                let link = HTMLElement(tagName: "span", attributes: [
                    "data-awful-linkified-image": ""])
                link.textContent = src
                img.parent?.replace(child: img, with: link)
            }
        }
    }
    
    /**
     Modifies the document in place, deleting all elements with the `editedby` class that have no text content.
     */
    func removeEmptyEditedByParagraphs() {
        for p in nodes(matchingSelector: "p.editedby") {
            if p.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                p.removeFromParentNode()
            }
        }
    }
    
    /**
     Modifies the document in place, removing the `style`, `onmouseover`, and `onmouseout` attributes from `bbc-spoiler` spans.
     */
    func removeSpoilerStylingAndEvents() {
        for element in nodes(matchingSelector: "span.bbc-spoiler") {
            element.removeAttribute(withName: "onmouseover")
            element.removeAttribute(withName: "onmouseout")
            element.removeAttribute(withName: "style")
        }
    }
    
    /**
     Modifies the document in place to stop GIFs at various hosts from autoplaying.
     */
    func stopGIFAutoplay() {
        for img in nodes(matchingSelector: "img") {
            guard
                let src = img["src"],
                let url = URL(string: src),
                let host = url.host,
                url.pathExtension.lowercased() == "gif",
                let imgParent = img.parentElement
                else { continue }
            
            let replacementSrc: String
            switch CaseInsensitive(host) {
                
            case _ where host.lowercased().hasSuffix("imgur.com"):
                replacementSrc = url.absoluteString.replacingOccurrences(of: ".gif", with: "h.jpg")
                
            case "i.kinja-img.com":
                replacementSrc = url.absoluteString.replacingOccurrences(of: ".gif", with: ".jpg")
                
            case "i.giphy.com":
                replacementSrc = url.absoluteString
                    .replacingOccurrences(of: "://i.giphy.com", with: "s://media.giphy.com/media")
                    .replacingOccurrences(of: ".gif", with: "/200_s.gif")
                
            case "giant.gfycat.com":
                replacementSrc = url.absoluteString
                    .replacingOccurrences(of: "giant.gfycat.com", with: "thumbs.gfycat.com")
                    .replacingOccurrences(of: ".gif", with: "-poster.jpg")
                
            default:
                continue
            }
            
            let replacementImg = HTMLElement(tagName: "img", attributes: [
                "src": replacementSrc,
                "class": "posterized",
                "data-original-url": url.absoluteString])
            let wrapper = HTMLElement(tagName: "div", attributes: [
                "class": "gif-wrap"])
            replacementImg.parent = wrapper
            
            let imgSiblings = imgParent.mutableChildren
            
            if imgParent.tagName == "a", let href = imgParent["href"], let linkTarget = URL(string: href) {
                let link = HTMLElement(tagName: "a", attributes: ["href": linkTarget.absoluteString])
                link.textContent = linkTarget.absoluteString
                imgSiblings.insert(link, at: imgSiblings.index(of: img))
            }
            
            imgSiblings.replaceObject(at: imgSiblings.index(of: img), with: wrapper)
        }
    }
    
    /**
     Modifies the document in place, replacing Flash-based Vimeo players with HTML5-based players.
     */
    func useHTML5VimeoPlayer() {
        for param in nodes(matchingSelector: "div.bbcode_video object param[name='movie'][value*='://vimeo.com/']") {
            guard
                let value = param["value"],
                let sourceURL = URL(string: value),
                let clipID = sourceURL.valueForFirstQueryItem(named: "clip_id"),
                let object = param.parentElement,
                object.tagName == "object",
                let div = object.parentElement,
                div.tagName == "div",
                div.hasClass("bbcode_video")
                else { continue }
            
            var iframeSrcComponents = URLComponents(string: "https://player.vimeo.com/video/")!
            iframeSrcComponents.path = iframeSrcComponents.path + clipID
            iframeSrcComponents.query = "byline=0&portrait=0"
            guard let iframeSrc = iframeSrcComponents.url else { continue }
            
            let iframe = HTMLElement(tagName: "iframe", attributes: [
                "src": iframeSrc.absoluteString,
                "width": object["width"] ?? "400",
                "height": object["height"] ?? "225",
                "frameborder": "0",
                "webkitAllowFullScreen": "",
                "allowFullScreen": ""])
            
            if let divSiblings = div.parent?.mutableChildren {
                divSiblings.replaceObject(at: divSiblings.index(of: div), with: iframe)
            }
        }
    }
}

extension URL {
    func valueForFirstQueryItem(named name: String) -> String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return nil }
        return (components.queryItems ?? []).first { $0.name == name }?.value
    }
}

/**
 Returns an updated Postimage URL for the provided URL, if one is available.
 
 Postimage changed the domain where they host images, so old URLs are now broken. Fortunately it's an easy fix.
 */
private func fixPostimageURL(_ url: URL) -> URL? {
    let oldHostSuffix = "postimg.org"
    guard
        var oldHost = url.host,
        oldHost.lowercased().hasSuffix(oldHostSuffix),
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return nil }
    
    oldHost.replaceSubrange(oldHost.index(oldHost.endIndex, offsetBy: -oldHostSuffix.count)..., with: "postimg.cc")
    components.host = oldHost
    return components.url
}

private func isSmilieURL(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    let components = url.pathComponents
    
    switch CaseInsensitive(host) {
    case "fi.somethingawful.com":
        return components.contains("smilies")
            || components.contains("posticons")
            || components.contains("customtitles")
        
    case "i.somethingawful.com":
        return components.contains("emot")
            || components.contains("emoticons")
            || components.contains("images")
            || (components.contains("u")
                && (components.contains("adminuploads") || components.contains("garbageday")))
        
    case "forumimages.somethingawful.com":
        return components.first == "images"
            || components.contains("posticons")
        
    // Games of Mafia
    case "media.votefinder.org":
        return true
        
    default:
        return false
    }
}

/**
 Turns a waffleimages.com URL into a randomwaffle.gbs.fm URL.
 
 Examples:
 
 * http://img.waffleimages.com/1df43ff210a2867f4e53faa40322e877f62897e4/t/DSC_0736.JPG
 * http://img.waffleimages.com/43bc914050a09db4e3df87289eb4b0e38e9e33eb/butter.jpg
 * http://img.waffleimages.com/images/7e/7e4178f6e4d086a7f418aa66cdffb64c32cd8c4c.jpg
 */
private func randomwaffleURLForWaffleimagesURL(_ url: URL) -> URL? {
    guard let scheme = url.scheme, scheme.lowercased().hasPrefix("http") else { return nil }
    guard let host = url.host, host.lowercased().hasSuffix("waffleimages.com") else { return nil }
    guard url.pathComponents.count >= 2 else { return nil }
    guard !url.pathExtension.isEmpty else { return nil }
    
    let hash: String
    if url.pathComponents.count == 4, url.pathComponents[1].lowercased() == "images" {
        hash = (url.pathComponents[3] as NSString).deletingPathExtension
    }
    else {
        hash = url.pathComponents[1]
    }
    guard hash.count >= 2 else { return nil }
    let hashPrefix = String(hash[..<hash.index(hash.startIndex, offsetBy: 2)])
    
    var pathExtension = url.pathExtension
    if pathExtension.caseInsensitiveCompare("jpeg") == .orderedSame {
        pathExtension = "jpg"
    }
    
    // Pretty sure NSURLComponents init should always succeed from a URL.
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    components.host = "randomwaffle.gbs.fm"
    components.path = "/images/\(hashPrefix)/\(hash).\(pathExtension)"
    return components.url
}
