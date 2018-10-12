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
     Modifies the document in place, adding the "mention" class to the header above a quote if it says "username posted:".
     */
    func highlightQuotesOfPosts(byUserNamed username: String) {
        let loggedInUserPosted = "\(username) posted:"
        for h4 in nodes(matchingSelector: ".bbc-block h4") where h4.textContent == loggedInUserPosted {
            var block = h4.parentElement
            while block != nil, block?.hasClass("bbc-block") == false {
                block = block?.parentElement
            }
            block?.toggleClass("mention")
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
     Modifies the document in place:
     
     * Turns all non-smiley `<img src=>` elements into `<a data-awful='image'>src</a>` elements (if linkifyNonSmiles == true).
     * Adds .awful-smile to smilie elements.
     */
    func processImgTags(shouldLinkifyNonSmilies: Bool) {
        for img in nodes(matchingSelector: "img") {
            guard let src = img["src"] else { continue }
            
            if let url = URL(string: src), isSmilieURL(url) {
                img.toggleClass("awful-smile")
            }
            else if shouldLinkifyNonSmilies {
                let link = HTMLElement(tagName: "span", attributes: [
                    "data-awful-linkified-image": ""])
                link.textContent = src
                if let siblings = img.parent?.mutableChildren {
                    siblings.replaceObject(at: siblings.index(of: img), with: link)
                }
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
                "class": "imgurGif",
                "data-originalurl": url.absoluteString,
                "data-posterurl": replacementSrc])
            let wrapper = HTMLElement(tagName: "div", attributes: ["class": "gifWrap"])
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
            
            var iframeSrcComponents = URLComponents(string: "https://player.vimeo.com/video/") !! "hardcoded"
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
