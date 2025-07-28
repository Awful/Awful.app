//  CompositionMenuTree.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MobileCoreServices
import os
import Photos
import PSMenuItem
import UIKit
import AwfulSettings
import Foil
import ImgurAnonymousAPI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CompositionMenuTree")

/// Can take over UIMenuController to show a tree of composition-related items on behalf of a text view.
final class CompositionMenuTree: NSObject {
    // This class exists to expose the struct-defined menu to Objective-C and to act as an image picker delegate.
    
    @FoilDefaultStorage(Settings.imgurUploadMode) private var imgurUploadMode
    
    fileprivate var imgurUploadsEnabled: Bool {
        return imgurUploadMode != .off
    }
    
    let textView: UITextView
    
    /// The textView's class will have some responder chain methods swizzled.
    init(textView: UITextView) {
        self.textView = textView
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
    
    func showImagePicker(_ sourceType: UIImagePickerController.SourceType) {
        // Check if we need to authenticate with Imgur first
        if ImgurAuthManager.shared.needsAuthentication {
            authenticateWithImgur()
            return
        }
        
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
    
    private func authenticateWithImgur() {
        guard let viewController = textView.nearestViewController else { return }
        
        // Show an alert to explain why authentication is needed
        let alert = UIAlertController(
            title: "Imgur Authentication Required",
            message: "You've enabled Imgur Account uploads in settings. To upload images with your account, you'll need to log in to Imgur.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Log In", style: .default) { _ in
            // Show loading indicator
            let loadingAlert = UIAlertController(
                title: "Connecting to Imgur",
                message: "Please wait...",
                preferredStyle: .alert
            )
            viewController.present(loadingAlert, animated: true)
            
            ImgurAuthManager.shared.authenticate(from: viewController) { success in
                // Dismiss loading indicator
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if success {
                            // If authentication was successful, continue with the upload
                            // Show a success message
                            let successAlert = UIAlertController(
                                title: "Successfully Logged In",
                                message: "You're now logged in to Imgur and can upload images with your account.",
                                preferredStyle: .alert
                            )
                            
                            successAlert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
                                // Continue with image picker after successful authentication
                                self.showImagePicker(.photoLibrary)
                            })
                            
                            viewController.present(successAlert, animated: true)
                        } else {
                            // Check if it's a rate limiting issue (check logs from ImgurAuthManager)
                            let isRateLimited = UserDefaults.standard.bool(forKey: ImgurAuthManager.DefaultsKeys.rateLimited)
                            
                            if isRateLimited {
                                // Show specific rate limiting error
                                let rateLimitAlert = UIAlertController(
                                    title: "Imgur Rate Limit Exceeded",
                                    message: "Imgur's API is currently rate limited. You can try again later or use anonymous uploads for now.",
                                    preferredStyle: .alert
                                )
                                
                                rateLimitAlert.addAction(UIAlertAction(title: "Use Anonymous Uploads", style: .default) { _ in
                                    // Switch to anonymous uploads for this session
                                    self.imgurUploadMode = .anonymous
                                    // Continue with image picker
                                    self.showImagePicker(.photoLibrary)
                                })
                                
                                rateLimitAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                
                                viewController.present(rateLimitAlert, animated: true)
                            } else {
                                // General authentication failure
                                let failureAlert = UIAlertController(
                                    title: "Authentication Failed",
                                    message: "Could not log in to Imgur. You can try again or choose anonymous uploads in settings.",
                                    preferredStyle: .alert
                                )
                                
                                failureAlert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
                                    // Try authentication again
                                    self.authenticateWithImgur()
                                })
                                
                                failureAlert.addAction(UIAlertAction(title: "Use Anonymous Upload", style: .default) { _ in
                                    // Use anonymous uploads for this session
                                    self.imgurUploadMode = .anonymous
                                    // Continue with image picker
                                    self.showImagePicker(.photoLibrary)
                                })
                                
                                failureAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                
                                viewController.present(failureAlert, animated: true)
                            }
                        }
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Use Anonymous Upload", style: .default) { _ in
            // Use anonymous uploads just for this session
            self.imgurUploadMode = .anonymous
            // Show image picker with anonymous uploads
            self.showImagePicker(.photoLibrary)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
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
        
        if let asset = info[.phAsset] as? PHAsset {
            insertImage(image, withAssetIdentifier: asset.localIdentifier)
        } else {
            insertImage(image)
        }

        picker.dismiss(animated: true, completion: {
            self.textView.becomeFirstResponder()
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: {
            self.textView.becomeFirstResponder()
        })
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        textView.becomeFirstResponder()
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
    
    func psItem(_ tree: CompositionMenuTree) {
        return
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
    /**
        Temporarily disabling the menu items that attempt image uploads. This is a bandaid fix and no imgur uploading code is being removed from the app at this time.
        TODO: Re-enable these menu items as part of a proper imgur replacement update. (imgur is deleting anonymous inactive images)
     
        original line: MenuItem(title: "[img]", action: { $0.showSubmenu(imageItems) }),
     */
    MenuItem(title: "[img]", action: { tree in
        // If Imgur uploads are enabled in settings, show the full image submenu
        // Otherwise, only allow pasting URLs
        if tree.imgurUploadsEnabled {
            tree.showSubmenu(imageItems)
        } else {
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

fileprivate let imageItems = [
    MenuItem(title: "From Camera", action: { $0.showImagePicker(.camera) }, enabled: isPickerAvailable(.camera)),
    MenuItem(title: "From Library", action: { $0.showImagePicker(.photoLibrary) }, enabled: isPickerAvailable(.photoLibrary)),
    MenuItem(title: "[img]", action: wrapSelectionInTag("[img]")),
    MenuItem(title: "Paste [img]", action:{ tree in
        if let text = UIPasteboard.general.coercedURL {
            if let textRange = tree.textView.selectedTextRange {
                tree.textView.replace(textRange, withText:("[img]" + UIPasteboard.general.coercedURL!.absoluteString + "[/img]"))
            }
        }
    }, enabled: { UIPasteboard.general.coercedURL != nil }),
    MenuItem(title: "Paste", action: { tree in
        if let image = UIPasteboard.general.image {
            tree.insertImage(image)
        }
        }, enabled: { UIPasteboard.general.image != nil })
]

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
