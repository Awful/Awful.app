//  URLCleaningTextView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import UIKit

/// Details of URLs that had tracking parameters stripped on their way into a text view, so the owner can offer to restore the originals.
struct URLCleaningNotice {
    struct Replacement {
        /// The full URL string before cleaning.
        let original: String
        /// The cleaned URL string now present in the text view.
        let cleaned: String
        /// Range of `cleaned` in the text view's text at insertion time.
        let range: NSRange
    }
    var replacements: [Replacement]

    /// User-facing summary for the "Use Original" banner.
    var bannerMessage: String {
        replacements.count == 1
            ? "Tracking removed"
            : "Tracking removed from \(replacements.count) links"
    }
}

/// A text view that strips tracking parameters from URLs in pasted text, then tells its owner what changed.
class URLCleaningTextView: UITextView {

    @FoilDefaultStorage(Settings.cleanPastedURLs) private var cleanPastedURLs

    /// Called after any insertion that stripped tracking parameters. Set by the owning view controller (e.g. to show a "Use Original" banner).
    var onURLsCleaned: ((URLCleaningNotice) -> Void)?

    override func paste(_ sender: Any?) {
        guard cleanPastedURLs else { return super.paste(sender) }
        let pasteboard = UIPasteboard.general
        guard !pasteboard.hasImages,
              let pasted = pasteboard.string ?? pasteboard.coercedURL?.absoluteString
        else { return super.paste(sender) }
        let result = TrackingParameterRemover.cleanedText(pasted)
        guard result.didChange,
              let selection = selectedTextRange
        else { return super.paste(sender) }

        let insertionLocation = selectedRange.location
        // Never touch the pasteboard itself; insert via UITextInput so undo and textDidChange notifications work (draft autosave relies on the latter).
        replace(selection, withText: result.cleanedText)
        let replacements = result.replacements.map {
            URLCleaningNotice.Replacement(
                original: $0.original,
                cleaned: $0.cleaned,
                range: NSRange(location: insertionLocation + $0.range.location, length: $0.range.length)
            )
        }
        onURLsCleaned?(URLCleaningNotice(replacements: replacements))
    }

    /// Lets the bbcode insertion helpers route their own cleaning events through the same owner callback.
    func reportCleaned(_ notice: URLCleaningNotice) {
        onURLsCleaned?(notice)
    }
}

extension UITextView {
    /// Swaps cleaned URLs back to their originals: first at each remembered range, falling back to a text search if intervening edits moved things around.
    func restoreOriginalURLs(from notice: URLCleaningNotice) {
        let replacements = notice.replacements.sorted { $0.range.location > $1.range.location }
        for replacement in replacements {
            let nsText = text as NSString
            let target: NSRange
            if NSMaxRange(replacement.range) <= nsText.length,
               nsText.substring(with: replacement.range) == replacement.cleaned {
                target = replacement.range
            } else {
                let found = nsText.range(of: replacement.cleaned)
                guard found.location != NSNotFound else { continue }
                target = found
            }
            guard let start = position(from: beginningOfDocument, offset: target.location),
                  let end = position(from: start, offset: target.length),
                  let textRange = textRange(from: start, to: end)
            else { continue }
            replace(textRange, withText: replacement.original)
        }
    }
}
