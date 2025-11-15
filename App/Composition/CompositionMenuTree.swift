//  CompositionMenuTree.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Foil
import ImgurAnonymousAPI
import MobileCoreServices
import os
import Photos
import PSMenuItem
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CompositionMenuTree")

/// Can take over UIMenuController to show a tree of composition-related items on behalf of a text view.
final class CompositionMenuTree: NSObject {
    @FoilDefaultStorage(Settings.imgurUploadMode) private var imgurUploadMode

    fileprivate var imgurUploadsEnabled: Bool {
        return imgurUploadMode != .off
    }

    let textView: UITextView
    weak var draft: (NSObject & ReplyDraft)?
    var onAttachmentChanged: (() -> Void)?
    var onResizingStarted: (() -> Void)?

    private let imageProcessingQueue = DispatchQueue(label: "com.awful.attachment.processing", qos: .userInitiated)
    private var pendingImage: UIImage?
    private var pendingImageAssetIdentifier: String?
    private let imageProcessingLock = NSLock()
    private var _isProcessingImage = false

    private func tryStartProcessing() -> Bool {
        imageProcessingLock.lock()
        defer { imageProcessingLock.unlock() }

        guard !_isProcessingImage else { return false }
        _isProcessingImage = true
        return true
    }

    private func finishProcessing() {
        imageProcessingLock.lock()
        defer { imageProcessingLock.unlock() }
        _isProcessingImage = false
    }

    private func clearPendingImage() {
        pendingImage = nil
        pendingImageAssetIdentifier = nil
        finishProcessing()
    }

    /// The textView's class will have some responder chain methods swizzled.
    init(textView: UITextView, draft: (NSObject & ReplyDraft)? = nil) {
        self.textView = textView
        self.draft = draft
        super.init()

        PSMenuItem.installMenuHandler(for: textView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(UITextViewDelegate.textViewDidBeginEditing(_:)), name: UITextView.textDidBeginEditingNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(UITextViewDelegate.textViewDidEndEditing(_:)), name: UITextView.textDidEndEditingNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(CompositionMenuTree.menuDidHide(_:)), name: UIMenuController.didHideMenuNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func textViewDidBeginEditing(_ note: NSNotification) {
        popToRootItems()
    }
    
    @objc private func textViewDidEndEditing(_ note: NSNotification) {
        UIMenuController.shared.menuItems = nil
    }
    
    @objc private func menuDidHide(_ note: NSNotification) {
        if shouldPopWhenMenuHides && textView.window != nil {
            popToRootItems()
        }
    }
    
    private var shouldPopWhenMenuHides = true
    
    private var targetRect: CGRect {
        return textView.selectedRect ?? textView.bounds
    }
    
    fileprivate func popToRootItems() {
        UIMenuController.shared.menuItems = psItemsForMenuItems(items: rootItems)
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = false
    }
    
    fileprivate func showSubmenu(_ submenu: [MenuItem]) {
        shouldPopWhenMenuHides = false
        
        UIMenuController.shared.menuItems = psItemsForMenuItems(items: submenu)
        // Simply calling UIMenuController.update() here doesn't suffice; the menu simply hides. Instead we need to hide the menu then show it again.
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = true

        UIMenuController.shared.hideMenu()
        if textView.selectedTextRange != nil {
            UIMenuController.shared.showMenu(from: textView, rect: targetRect)
        } else {
            UIMenuController.shared.showMenu(from: textView, rect: textView.bounds)
        }
        
        shouldPopWhenMenuHides = true
    }

    // fileprivate to allow access from MenuItem action closures defined at file scope
    fileprivate func showImagePicker(_ sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        let mediaType = UTType.image
        picker.mediaTypes = [mediaType.identifier]
        picker.allowsEditing = false
        picker.delegate = self
        if UIDevice.current.userInterfaceIdiom == .pad && sourceType == .photoLibrary {
            picker.modalPresentationStyle = .popover
            if let popover = picker.popoverPresentationController {
                popover.sourceRect = targetRect
                popover.sourceView = textView
                popover.delegate = self
            }
        }
        textView.nearestViewController?.present(picker, animated: true, completion: nil)
    }

    // MARK: - Imgur Authentication

    private func authenticateWithImgur() {
        guard let viewController = textView.nearestViewController else { return }
        showAuthenticationPrompt(in: viewController)
    }

    private func showAuthenticationPrompt(in viewController: UIViewController) {
        presentAlert(
            in: viewController,
            title: "Imgur Authentication Required",
            message: "You've enabled Imgur Account uploads in settings. To upload images with your account, you'll need to log in to Imgur.",
            actions: [
                ("Log In", .default, { [weak self] in
                    self?.performAuthentication(in: viewController)
                }),
                ("Use Anonymous Upload", .default, { [weak self] in
                    self?.switchToAnonymousUploads()
                }),
                ("Cancel", .cancel, nil)
            ]
        )
    }

    private func performAuthentication(in viewController: UIViewController) {
        let loadingAlert = UIAlertController(
            title: "Connecting to Imgur",
            message: "Please wait...",
            preferredStyle: .alert
        )
        viewController.present(loadingAlert, animated: true)

        ImgurAuthManager.shared.authenticate(from: viewController) { [weak self] success in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    self?.handleAuthenticationResult(success, in: viewController)
                }
            }
        }
    }

    private func handleAuthenticationResult(_ success: Bool, in viewController: UIViewController) {
        if success {
            presentAuthenticationSuccessAlert(in: viewController)
        } else {
            let isRateLimited = UserDefaults.standard.bool(forKey: ImgurAuthManager.DefaultsKeys.rateLimited)
            if isRateLimited {
                presentRateLimitAlert(in: viewController)
            } else {
                presentAuthenticationFailureAlert(in: viewController)
            }
        }
    }

    private func presentAuthenticationSuccessAlert(in viewController: UIViewController) {
        presentAlert(
            in: viewController,
            title: "Successfully Logged In",
            message: "You're now logged in to Imgur and can upload images with your account.",
            actions: [
                ("Continue", .default, { [weak self] in
                    self?.showImagePicker(.photoLibrary)
                })
            ]
        )
    }

    private func presentRateLimitAlert(in viewController: UIViewController) {
        presentAlert(
            in: viewController,
            title: "Imgur Rate Limit Exceeded",
            message: "Imgur's API is currently rate limited. You can try again later or use anonymous uploads for now.",
            actions: [
                ("Use Anonymous Uploads", .default, { [weak self] in
                    self?.switchToAnonymousUploads()
                }),
                ("Cancel", .cancel, nil)
            ]
        )
    }

    private func presentAuthenticationFailureAlert(in viewController: UIViewController) {
        presentAlert(
            in: viewController,
            title: "Authentication Failed",
            message: "Could not log in to Imgur. You can try again or choose anonymous uploads in settings.",
            actions: [
                ("Try Again", .default, { [weak self] in
                    self?.authenticateWithImgur()
                }),
                ("Use Anonymous Upload", .default, { [weak self] in
                    self?.switchToAnonymousUploads()
                }),
                ("Cancel", .cancel, nil)
            ]
        )
    }

    private func switchToAnonymousUploads() {
        imgurUploadMode = .anonymous
        showImagePicker(.photoLibrary)
    }

    // MARK: - Alert Helper

    private func presentAlert(
        in viewController: UIViewController,
        title: String,
        message: String,
        actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)]
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        for (actionTitle, style, handler) in actions {
            alert.addAction(UIAlertAction(title: actionTitle, style: style) { _ in
                handler?()
            })
        }

        viewController.present(alert, animated: true)
    }
    
    func insertImage(_ image: UIImage, withAssetIdentifier assetID: String? = nil) {
        // Inserting the image changes our font and text color, so save those now and restore those later.
        let font = textView.font
        let textColor = textView.textColor
        
        let attachment = TextAttachment(image: image, photoAssetIdentifier: assetID)
        let string = NSAttributedString(attachment: attachment)

        // Directly modify the textStorage instead of setting a whole new attributedText on the UITextView, which can be slow and jumps the text view around. We'll need to post our own text changed notification too.
        let storage = textView.textStorage
        let originalSelectedRange = textView.selectedRange
        storage.beginEditing()
        storage.replaceCharacters(in: textView.selectedRange, with: string)
        textView.font = font
        textView.textColor = textColor
        storage.endEditing()
        
        // Calculate new cursor position after the inserted image
        let newCursorLocation = originalSelectedRange.location + string.length
        
        // Defer the selection update to avoid conflicts with the text system
        // This prevents the crash when the system tries to query text ranges during the update
        DispatchQueue.main.async { [weak textView] in
            guard let textView = textView else { return }
            
            // Ensure the new position is within valid bounds
            if newCursorLocation <= textView.textStorage.length {
                textView.selectedRange = NSRange(location: newCursorLocation, length: 0)
            } else {
                // If somehow we're beyond the text bounds, place cursor at the end
                textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
            }
        }
        
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
    }
    
    private func psItemsForMenuItems(items: [MenuItem]) -> [PSMenuItem] {
        return items.filter { $0.enabled() }
            .map { item in PSMenuItem(title: item.title) { item.action(self) } }
    }
}

extension CompositionMenuTree: UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController == navigationController.viewControllers.first {
            viewController.navigationItem.title = "Insert Image"
        }
    }
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
            logger.error("could not find image among image picker info")
            let alert = UIAlertController(title: "Could Not Find Image", message: "The chosen image could not be found", alertActions: [.ok()])
            textView.nearestViewController?.present(alert, animated: true)
            return
        }

        let assetIdentifier = (info[.phAsset] as? PHAsset)?.localIdentifier

        pendingImage = image
        pendingImageAssetIdentifier = assetIdentifier

        picker.dismiss(animated: true) {
            self.textView.becomeFirstResponder()
            self.showSubmenu(imageDestinationItems(tree: self))
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: {
            self.textView.becomeFirstResponder()
        })
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        textView.becomeFirstResponder()
    }

    fileprivate func useImageHostForPendingImage() {
        guard let image = pendingImage else { return }

        if ImgurAuthManager.shared.needsAuthentication {
            authenticateWithImgur()
            return
        }

        if let assetID = pendingImageAssetIdentifier {
            insertImage(image, withAssetIdentifier: assetID)
        } else {
            insertImage(image)
        }

        clearPendingImage()
    }

    fileprivate func useForumAttachmentForPendingImage() {
        guard let image = pendingImage else { return }
        guard tryStartProcessing() else {
            logger.warning("Image already being processed, ignoring concurrent request")
            return
        }

        let attachment = ForumAttachment(image: image, photoAssetIdentifier: pendingImageAssetIdentifier)

        if let error = attachment.validationError {
            handleAttachmentValidationError(error)
            return
        }

        applyAttachmentAndClear(attachment)
    }

    private func handleAttachmentValidationError(_ error: ForumAttachment.ValidationError) {
        if canResizeToFix(error) {
            presentResizePrompt(for: error)
        } else {
            presentValidationErrorAlert(error)
        }
    }

    private func canResizeToFix(_ error: ForumAttachment.ValidationError) -> Bool {
        switch error {
        case .fileTooLarge, .dimensionsTooLarge: return true
        default: return false
        }
    }

    private func presentResizePrompt(for error: ForumAttachment.ValidationError) {
        guard let viewController = textView.nearestViewController else { return }
        presentAlert(
            in: viewController,
            title: "Attachment Too Large",
            message: "\(error.localizedDescription)\n\nWould you like to automatically resize the image to fit?",
            actions: [
                ("Cancel", .cancel, { [weak self] in
                    self?.clearPendingImage()
                }),
                ("Resize & Continue", .default, { [weak self] in
                    self?.resizeAndAttachPendingImage()
                })
            ]
        )
    }

    private func presentValidationErrorAlert(_ error: ForumAttachment.ValidationError) {
        guard let viewController = textView.nearestViewController else { return }
        presentAlert(
            in: viewController,
            title: "Invalid Attachment",
            message: error.localizedDescription,
            actions: [("OK", .default, nil)]
        )
        clearPendingImage()
    }

    private func applyAttachmentAndClear(_ attachment: ForumAttachment) {
        draft?.forumAttachment = attachment
        clearPendingImage()
        onAttachmentChanged?()
    }

    private func resizeAndAttachPendingImage() {
        guard let image = pendingImage else { return }
        resizeAndAttach(image: image, assetIdentifier: pendingImageAssetIdentifier)
    }

    private func resizeAndAttach(image: UIImage, assetIdentifier: String?) {
        onResizingStarted?()

        imageProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            let resizedAttachment = autoreleasepool {
                ForumAttachment(image: image, photoAssetIdentifier: assetIdentifier).resized()
            }

            DispatchQueue.main.async { [weak self] in
                self?.handleResizeResult(resizedAttachment)
            }
        }
    }

    private func handleResizeResult(_ resizedAttachment: ForumAttachment?) {
        guard let attachment = resizedAttachment else {
            handleResizeFailure(message: "Unable to resize image to meet requirements.")
            return
        }

        if let error = attachment.validationError {
            handleResizeFailure(message: error.localizedDescription)
            return
        }

        handleResizeSuccess(attachment)
    }

    private func handleResizeFailure(message: String) {
        finishProcessing()
        onAttachmentChanged?()

        guard let viewController = textView.nearestViewController else { return }
        presentAlert(
            in: viewController,
            title: "Resize Failed",
            message: message,
            actions: [
                ("Try Again", .default, { [weak self] in
                    self?.resizeAndAttachPendingImage()
                }),
                ("Cancel", .cancel, { [weak self] in
                    self?.clearPendingImage()
                    self?.onAttachmentChanged?()
                })
            ]
        )
    }

    private func handleResizeSuccess(_ attachment: ForumAttachment) {
        clearPendingImage()
        draft?.forumAttachment = attachment
        onAttachmentChanged?()
    }
}

@objc protocol CompositionHidesMenuItems {
    var hidesBuiltInMenuItems: Bool { get set }
}

fileprivate struct MenuItem {
    var title: String
    var action: (CompositionMenuTree) -> Void
    var enabled: () -> Bool
    
    init(title: String, action: @escaping (CompositionMenuTree) -> Void, enabled: @escaping () -> Bool) {
        self.title = title
        self.action = action
        self.enabled = enabled
    }
    
    init(title: String, action: @escaping (CompositionMenuTree) -> Void) {
        self.init(title: title, action: action, enabled: { true })
    }
}

fileprivate let rootItems = [
    MenuItem(title: "[url]", action: { tree in
        if UIPasteboard.general.coercedURL == nil {
            linkifySelection(tree)
        } else {
            tree.showSubmenu(URLItems)
        }
    }),
    MenuItem(title: "[img]", action: { tree in
        // Show the image submenu if Imgur uploads are enabled or forum attachments are available
        if tree.imgurUploadsEnabled || tree.draft is NewReplyDraft {
            tree.showSubmenu(imageItems(tree: tree))
        } else {
            // Fallback: paste image URL from clipboard or wrap selection
            if UIPasteboard.general.coercedURL == nil {
                linkifySelection(tree)
            } else {
                if let textRange = tree.textView.selectedTextRange {
                    tree.textView.replace(textRange, withText:("[img]" + UIPasteboard.general.coercedURL!.absoluteString + "[/img]"))
                }
            }
        }
    }),
    MenuItem(title: "Format", action: { $0.showSubmenu(formattingItems) }),
    MenuItem(title: "[video]", action: { tree in
        if let URL = UIPasteboard.general.coercedURL {
            if videoTagURLForURL(URL) != nil {
                return tree.showSubmenu(videoSubmenuItems)
            }
        }
        wrapSelectionInTag("[video]")(tree)
    })
]

fileprivate let URLItems = [
    MenuItem(title: "[url]", action: linkifySelection),
    MenuItem(title: "Paste", action: { tree in
        if let URL = UIPasteboard.general.coercedURL {
            wrapSelectionInTag("[url=\(URL.absoluteString)]" as NSString)(tree)
        }
    })
]

fileprivate func imageItems(tree: CompositionMenuTree) -> [MenuItem] {
    var items: [MenuItem] = []

    if UIPasteboard.general.coercedURL != nil {
        items.append(MenuItem(title: "Paste URL", action: { tree in
            if let textRange = tree.textView.selectedTextRange {
                tree.textView.replace(textRange, withText:("[img]" + UIPasteboard.general.coercedURL!.absoluteString + "[/img]"))
            }
        }))
    }

    items.append(contentsOf: [
        MenuItem(title: "From Library", action: { $0.showImagePicker(.photoLibrary) }, enabled: isPickerAvailable(.photoLibrary)),
        MenuItem(title: "[img]", action: wrapSelectionInTag("[img]"))
    ])

    return items
}

fileprivate func imageDestinationItems(tree: CompositionMenuTree) -> [MenuItem] {
    var items: [MenuItem] = []

    if tree.imgurUploadsEnabled {
        items.append(MenuItem(title: "Image Host", action: { $0.useImageHostForPendingImage() }))
    }

    if tree.draft is NewReplyDraft {
        items.append(MenuItem(title: "Forum Attachment", action: { $0.useForumAttachmentForPendingImage() }))
    }

    return items
}

fileprivate let formattingItems = [
    MenuItem(title: "[b]", action: wrapSelectionInTag("[b]")),
    MenuItem(title: "[i]", action: wrapSelectionInTag("[i]")),
    MenuItem(title: "[s]", action: wrapSelectionInTag("[s]")),
    MenuItem(title: "[u]", action: wrapSelectionInTag("[u]")),
    MenuItem(title: "[spoiler]", action: wrapSelectionInTag("[spoiler]")),
    MenuItem(title: "[fixed]", action: wrapSelectionInTag("[fixed]")),
    MenuItem(title: "[quote]", action: wrapSelectionInTag("[quote=]\n")),
    MenuItem(title: "[code]", action: wrapSelectionInTag("[code]\n")),
]

fileprivate let videoSubmenuItems = [
    MenuItem(title: "[video]", action: wrapSelectionInTag("[video]")),
    MenuItem(title: "Paste", action: { tree in
        if
            let copiedURL = UIPasteboard.general.coercedURL,
            let URL = videoTagURLForURL(copiedURL as URL)
        {
            let textView = tree.textView
            if let selectedTextRange = textView.selectedTextRange {
                let tag = "[video]\(URL.absoluteString)[/video]"
                let textView = tree.textView
                textView.replace(selectedTextRange, withText: tag)
                textView.selectedRange = NSRange(location: textView.selectedRange.location + (tag as NSString).length, length: 0)
            }
        }
    })
]

fileprivate func videoTagURLForURL(_ url: URL) -> URL? {
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
            queryItems.insert(URLQueryItem(name: "v", value: videoID) as URLQueryItem, at: 0)
            components.queryItems = queryItems
            return components.url
        }
        return nil
    case let (host?, path) where host.hasSuffix("tiktok.com") && path.hasPrefix("/embed"):
        return url
    case let (host?, path) where host.hasSuffix("tiktok.com")
        // Share URL from TikTok has this format: /@{user}/video/{videoID} but the forums will convert
        && path.range(of: "/@[^/]+/video/.+", options: [.regularExpression, .anchored]) != nil:
        return url
    default:
        return nil
    }
}

fileprivate func linkifySelection(_ tree: CompositionMenuTree) {
    var detector : NSDataDetector = NSDataDetector()
    do {
        detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }
    catch {
        return logger.error("error creating link data detector: \(error)")
    }
    
    let textView = tree.textView
    if let selectionRange = textView.selectedTextRange {
        let selection: NSString = textView.text(in: selectionRange)! as NSString
        let matches = detector.matches(in: selection as String, options: [], range: NSRange(location: 0, length: selection.length))
        if let firstMatchLength = matches.first?.range.length {
            if firstMatchLength == selection.length && selection.length > 0 {
                return wrapSelectionInTag("[url]")(tree)
            }
        }
    }
    
    wrapSelectionInTag("[url=]")(tree)
}

/**
tagspec specifies which tag to insert, with optional newlines and attribute insertion. For example:

- [b] puts plain opening and closing tags around the selection.
- [code]\n does the above plus inserts a newline after the opening tag and before the closing tag.
- [quote=]\n does the above plus inserts an = sign within the opening tag and, after wrapping, places the cursor after it.
- [url=http://example.com] puts an opening and closing tag around the selection with the attribute intact in the opening tag and, after wrapping, places the cursor after the closing tag.
*/
fileprivate func wrapSelectionInTag(_ tagspec: NSString) -> (_ tree: CompositionMenuTree) -> Void {
    return { tree in
        let textView = tree.textView
        
        var equalsPart = tagspec.range(of: "=")
        let end = tagspec.range(of: "]")
        if equalsPart.location != NSNotFound {
            equalsPart.length = end.location - equalsPart.location
        }
        
        let closingTag = NSMutableString(string: tagspec)
        if equalsPart.location != NSNotFound {
            closingTag.deleteCharacters(in: equalsPart)
        }
        closingTag.insert("/", at: 1)
        if tagspec.hasSuffix("\n") {
            closingTag.insert("\n", at: 0)
        }
        
        var selectedRange = textView.selectedRange
        
        if let selection = textView.selectedTextRange {
            textView.replace(textView.textRange(from: selection.end, to: selection.end)!, withText: closingTag as String)
            textView.replace(textView.textRange(from: selection.start, to: selection.start)!, withText: tagspec as String)
        }
        
        if equalsPart.location == NSNotFound && !tagspec.hasSuffix("\n") {
            selectedRange.location += tagspec.length
        } else if equalsPart.length == 1 {
            selectedRange.location += NSMaxRange(equalsPart)
        } else if selectedRange.length == 0 {
            selectedRange.location += NSMaxRange(end) + 1
        } else {
            selectedRange.location += selectedRange.length + tagspec.length + closingTag.length
            selectedRange.length = 0
        }
        textView.selectedRange = selectedRange
        textView.becomeFirstResponder()
    }
}

fileprivate func isPickerAvailable(_ sourceType: UIImagePickerController.SourceType) -> () -> Bool {
    return {
        return UIImagePickerController.isSourceTypeAvailable(sourceType)
    }
}
