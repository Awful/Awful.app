//  ModernToolbarActions.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import UIKit

/**
 Handles the `ModernBBcodeToolbar` actions that every composition screen deals with identically.

 Two separate view controllers show this toolbar — `CompositionViewController` for replies, and
 `ComposeTextViewController` for new threads and private messages — so the prompts live here rather
 than in either one of them.
 */
@MainActor
protocol ModernToolbarActionHandling: UIViewController {

    /// The text view the toolbar inserts tags into.
    var toolbarTextView: URLCleaningTextView { get }

    /// Supplies the image picker and clipboard-paste destinations, where there are any.
    var toolbarMenuTree: CompositionMenuTree? { get }
}

extension ModernToolbarActionHandling {

    func handleModernToolbarAction(_ action: ModernToolbarAction) {
        switch action {
        case .url:
            showURLPrompt()
        case .image:
            showImageOptions()
        case .format(let option):
            BBcodeTagHelper(textView: toolbarTextView).applyFormat(option)
        case .video:
            showVideoPrompt()
        case .poll, .specs:
            // Only one composer offers each of these buttons (poll: new thread; specs: reply in
            // the feedback thread), and it intercepts the action before handing anything else
            // over to us.
            break
        }
    }

    // MARK: - Tracking removal

    /// Cleans tracking parameters out of a user-entered URL string when the setting is on. Returns
    /// the string to insert, plus the original when cleaning changed it (else `nil`).
    func cleanedURLString(_ urlString: String) -> (cleaned: String, originalIfChanged: String?) {
        guard UserDefaults.standard.defaultingValue(for: Settings.cleanPastedURLs) else { return (urlString, nil) }
        let result = TrackingParameterRemover.cleanedText(urlString)
        guard result.didChange else { return (urlString, nil) }
        return (result.cleanedText, urlString)
    }

    func reportIfCleaned(original: String?, cleaned: String, at location: Int) {
        guard let original else { return }
        toolbarTextView.reportCleaned(URLCleaningNotice(replacements: [
            .init(
                original: original,
                cleaned: cleaned,
                range: NSRange(location: location, length: (cleaned as NSString).length)
            ),
        ]))
    }

    // MARK: - URL and video prompts

    func showURLPrompt() {
        let alert = UIAlertController(title: "Insert Link", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "URL (e.g., https://example.com)"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addTextField { [weak self] textField in
            textField.placeholder = "Display text (optional)"
            if let selection = self?.toolbarTextView.selectedTextRange,
               let selectedText = self?.toolbarTextView.text(in: selection),
               !selectedText.isEmpty {
                textField.text = selectedText
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            let url = alert.textFields?[0].text ?? ""
            let displayText = alert.textFields?[1].text ?? ""
            self?.insertURLTag(url: url, displayText: displayText)
        })

        present(alert, animated: true)
    }

    private func insertURLTag(url: String, displayText: String) {
        guard !url.isEmpty else { return }
        let (cleaned, original) = cleanedURLString(url)
        let helper = BBcodeTagHelper(textView: toolbarTextView)
        let insertionStart = toolbarTextView.selectedRange.location
        if displayText.isEmpty {
            helper.insertText("[url]\(cleaned)[/url]")
            reportIfCleaned(original: original, cleaned: cleaned, at: insertionStart + ("[url]" as NSString).length)
        } else {
            helper.insertText("[url=\(cleaned)]\(displayText)[/url]")
            reportIfCleaned(original: original, cleaned: cleaned, at: insertionStart + ("[url=" as NSString).length)
        }
    }

    func showVideoPrompt() {
        let alert = UIAlertController(title: "Insert Video", message: "Supported: YouTube, Vimeo, TikTok, CNN, Yahoo, FOXNews", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Video URL"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            guard let urlString = alert.textFields?[0].text, !urlString.isEmpty else { return }
            self?.insertVideoTag(urlString: urlString)
        })

        present(alert, animated: true)
    }

    private func insertVideoTag(urlString: String) {
        let (cleaned, original) = cleanedURLString(urlString)
        let helper = BBcodeTagHelper(textView: toolbarTextView)
        let insertionStart = toolbarTextView.selectedRange.location
        if let url = URL(string: cleaned),
           let normalizedURL = BBcodeTagHelper.videoTagURL(for: url) {
            helper.insertText("[video]\(normalizedURL.absoluteString)[/video]")
            reportIfCleaned(original: original, cleaned: normalizedURL.absoluteString, at: insertionStart + ("[video]" as NSString).length)
        } else {
            helper.insertText("[video]\(cleaned)[/video]")
            reportIfCleaned(original: original, cleaned: cleaned, at: insertionStart + ("[video]" as NSString).length)
        }
    }

    // MARK: - Image options

    func showImageOptions() {
        let alert = UIAlertController(title: "Insert Image", message: nil, preferredStyle: .actionSheet)

        if BBcodeTagHelper.clipboardHasURL {
            alert.addAction(UIAlertAction(title: "Paste URL from Clipboard", style: .default) { [weak self] _ in
                guard let self else { return }
                if let (url, original) = UIPasteboard.general.cleanedCoercedURL {
                    let helper = BBcodeTagHelper(textView: self.toolbarTextView)
                    let insertionStart = self.toolbarTextView.selectedRange.location
                    helper.insertText("[img]\(url.absoluteString)[/img]")
                    self.reportIfCleaned(original: original?.absoluteString, cleaned: url.absoluteString, at: insertionStart + ("[img]" as NSString).length)
                }
            })
        }

        // New threads and private messages have no reply draft, so imgur is their only destination.
        let canAttachInEdit = (toolbarMenuTree?.draft as? EditReplyDraft)?.canAddAttachment ?? false
        let hasDestination: Bool = {
            guard let menuTree = toolbarMenuTree else { return false }
            return menuTree.imgurUploadsEnabled || menuTree.draft is NewReplyDraft || canAttachInEdit
        }()

        if UIPasteboard.general.hasImages && hasDestination {
            alert.addAction(UIAlertAction(title: "Paste Image from Clipboard", style: .default) { [weak self] _ in
                self?.toolbarMenuTree?.pasteImageFromClipboard()
            })
        }

        if hasDestination {
            alert.addAction(UIAlertAction(title: "From Library", style: .default) { [weak self] _ in
                self?.toolbarMenuTree?.showImagePicker(.photoLibrary)
            })
        }

        alert.addAction(UIAlertAction(title: "Enter URL", style: .default) { [weak self] _ in
            self?.showImagePrompt()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = toolbarTextView
            popover.sourceRect = toolbarTextView.selectedRect ?? toolbarTextView.bounds
        }

        present(alert, animated: true)
    }

    func showImagePrompt() {
        let alert = UIAlertController(title: "Insert Image", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Image URL"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            guard let self, let urlString = alert.textFields?[0].text, !urlString.isEmpty else { return }
            let (cleaned, original) = self.cleanedURLString(urlString)
            let helper = BBcodeTagHelper(textView: self.toolbarTextView)
            let insertionStart = self.toolbarTextView.selectedRange.location
            helper.insertText("[img]\(cleaned)[/img]")
            self.reportIfCleaned(original: original, cleaned: cleaned, at: insertionStart + ("[img]" as NSString).length)
        })

        present(alert, animated: true)
    }
}
