//  BBcodeTagHelper.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Helper for applying BBcode tags to a UITextView
struct BBcodeTagHelper {

    let textView: UITextView

    /// Format options for BBcode tags
    enum FormatOption: String, CaseIterable {
        case bold = "[b]"
        case italic = "[i]"
        case strikethrough = "[s]"
        case underline = "[u]"
        case spoiler = "[spoiler]"
        case fixed = "[fixed]"
        case quote = "[quote=]\n"
        case code = "[code]\n"

        var displayTitle: String {
            switch self {
            case .bold: return "[b]"
            case .italic: return "[i]"
            case .strikethrough: return "[s]"
            case .underline: return "[u]"
            case .spoiler: return "[spoiler]"
            case .fixed: return "[fixed]"
            case .quote: return "[quote]"
            case .code: return "[code]"
            }
        }

        var menuTitle: String {
            switch self {
            case .bold: return "Bold"
            case .italic: return "Italic"
            case .strikethrough: return "Strikethrough"
            case .underline: return "Underline"
            case .spoiler: return "Spoiler"
            case .fixed: return "Fixed Width"
            case .quote: return "Quote"
            case .code: return "Code"
            }
        }
    }

    /// Wraps the current selection in the specified BBcode tag
    ///
    /// tagspec specifies which tag to insert, with optional newlines and attribute insertion. For example:
    /// - `[b]` puts plain opening and closing tags around the selection.
    /// - `[code]\n` does the above plus inserts a newline after the opening tag and before the closing tag.
    /// - `[quote=]\n` does the above plus inserts an = sign within the opening tag and, after wrapping, places the cursor after it.
    /// - `[url=http://example.com]` puts an opening and closing tag around the selection with the attribute intact in the opening tag and, after wrapping, places the cursor after the closing tag.
    func wrapSelectionInTag(_ tagspec: String) {
        let nsTagspec = tagspec as NSString

        var equalsPart = nsTagspec.range(of: "=")
        let end = nsTagspec.range(of: "]")
        if equalsPart.location != NSNotFound {
            equalsPart.length = end.location - equalsPart.location
        }

        let closingTag = NSMutableString(string: nsTagspec)
        if equalsPart.location != NSNotFound {
            closingTag.deleteCharacters(in: equalsPart)
        }
        closingTag.insert("/", at: 1)
        if nsTagspec.hasSuffix("\n") {
            closingTag.insert("\n", at: 0)
        }

        var selectedRange = textView.selectedRange

        if let selection = textView.selectedTextRange {
            textView.replace(textView.textRange(from: selection.end, to: selection.end)!, withText: closingTag as String)
            textView.replace(textView.textRange(from: selection.start, to: selection.start)!, withText: tagspec)
        }

        if equalsPart.location == NSNotFound && !nsTagspec.hasSuffix("\n") {
            selectedRange.location += nsTagspec.length
        } else if equalsPart.length == 1 {
            selectedRange.location += NSMaxRange(equalsPart)
        } else if selectedRange.length == 0 {
            selectedRange.location += NSMaxRange(end) + 1
        } else {
            selectedRange.location += selectedRange.length + nsTagspec.length + closingTag.length
            selectedRange.length = 0
        }
        textView.selectedRange = selectedRange
        textView.becomeFirstResponder()
    }

    /// Apply a format option to the current selection
    func applyFormat(_ option: FormatOption) {
        wrapSelectionInTag(option.rawValue)
    }

    /// Insert a URL tag, optionally with a URL from clipboard
    func insertURLTag(withClipboardURL: Bool = false) {
        if withClipboardURL, let url = UIPasteboard.general.coercedURL {
            wrapSelectionInTag("[url=\(url.absoluteString)]")
        } else {
            // Check if selection is already a URL
            if let selectionRange = textView.selectedTextRange,
               let selection = textView.text(in: selectionRange),
               !selection.isEmpty {
                let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let matches = detector?.matches(in: selection, options: [], range: NSRange(location: 0, length: (selection as NSString).length)) ?? []
                if let firstMatch = matches.first, firstMatch.range.length == (selection as NSString).length {
                    wrapSelectionInTag("[url]")
                    return
                }
            }
            wrapSelectionInTag("[url=]")
        }
    }

    /// Insert an image tag, optionally with a URL from clipboard
    func insertImageTag(withClipboardURL: Bool = false) {
        if withClipboardURL, let url = UIPasteboard.general.coercedURL {
            if let textRange = textView.selectedTextRange {
                textView.replace(textRange, withText: "[img]\(url.absoluteString)[/img]")
            }
        } else {
            wrapSelectionInTag("[img]")
        }
    }

    /// Insert a video tag, optionally with a URL from clipboard
    func insertVideoTag(withClipboardURL: Bool = false) {
        if withClipboardURL,
           let copiedURL = UIPasteboard.general.coercedURL,
           let videoURL = Self.videoTagURL(for: copiedURL) {
            if let selectedTextRange = textView.selectedTextRange {
                let tag = "[video]\(videoURL.absoluteString)[/video]"
                textView.replace(selectedTextRange, withText: tag)
                textView.selectedRange = NSRange(location: textView.selectedRange.location + (tag as NSString).length, length: 0)
            }
        } else {
            wrapSelectionInTag("[video]")
        }
    }

    /// Check if a URL is a valid video URL for the [video] tag
    static func videoTagURL(for url: URL) -> URL? {
        switch (url.host?.lowercased(), url.path.lowercased()) {
        case let (host?, path) where host.hasSuffix("cnn.com") && path.hasPrefix("/video"):
            return url
        case let (host?, path) where host.hasSuffix("foxnews.com") && path.hasPrefix("/video"):
            return url
        case let (host?, _) where host.hasSuffix("video.yahoo.com"):
            return url
        case let (host?, _) where host.hasSuffix("vimeo.com"):
            return url
        case let (host?, path) where host.hasSuffix("youtube.com") && path.hasPrefix("/watch"):
            return url
        case let (host?, path) where host.hasSuffix("youtu.be") && path.count > 1:
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                let videoID = url.pathComponents[1]
                components.host = "www.youtube.com"
                components.path = "/watch"
                var queryItems = components.queryItems ?? []
                queryItems.insert(URLQueryItem(name: "v", value: videoID), at: 0)
                components.queryItems = queryItems
                return components.url
            }
            return nil
        case let (host?, path) where host.hasSuffix("tiktok.com") && path.hasPrefix("/embed"):
            return url
        case let (host?, path) where host.hasSuffix("tiktok.com")
            && path.range(of: "/@[^/]+/video/.+", options: [.regularExpression, .anchored]) != nil:
            return url
        default:
            return nil
        }
    }

    /// Check if clipboard contains a valid video URL
    static var clipboardHasVideoURL: Bool {
        guard let url = UIPasteboard.general.coercedURL else { return false }
        return videoTagURL(for: url) != nil
    }

    /// Check if clipboard contains a URL
    static var clipboardHasURL: Bool {
        return UIPasteboard.general.coercedURL != nil
    }

    /// Insert text at the current cursor position, replacing any selection
    func insertText(_ text: String) {
        if let selectedRange = textView.selectedTextRange {
            textView.replace(selectedRange, withText: text)
            // Move cursor to end of inserted text
            if let newPosition = textView.position(from: selectedRange.start, offset: text.count) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }
        textView.becomeFirstResponder()
    }
}
