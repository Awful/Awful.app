//  CompositionMenuTree.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PSMenuItem
import UIKit

/// Can take over UIMenuController to show a tree of composition-related items on behalf of a text view.
// This classes exists to expose the struct-defined menu to Objective-C and to act as an image picker delegate.
final class CompositionMenuTree: NSObject {
    let textView: UITextView
    
    /// The textView's class will have some responder chain methods swizzled.
    init(textView: UITextView) {
        self.textView = textView
        super.init()
        
        PSMenuItem.installMenuHandler(for: textView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(UITextViewDelegate.textViewDidBeginEditing(_:)), name: NSNotification.Name.UITextViewTextDidBeginEditing, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(UITextViewDelegate.textViewDidEndEditing(_:)), name: NSNotification.Name.UITextViewTextDidEndEditing, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(CompositionMenuTree.menuDidHide(_:)), name: NSNotification.Name.UIMenuControllerDidHideMenu, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func textViewDidBeginEditing(note: NSNotification) {
        popToRootItems()
    }
    
    @objc private func textViewDidEndEditing(note: NSNotification) {
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
        UIMenuController.shared.isMenuVisible = false
        if let _ = textView.selectedTextRange {
            UIMenuController.shared.setTargetRect(targetRect, in: textView)
        }
        UIMenuController.shared.setMenuVisible(true, animated: true)
        
        shouldPopWhenMenuHides = true
    }
    
    func showImagePicker(_ sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        let mediaType : NSString = kUTTypeImage as NSString
        picker.mediaTypes = [mediaType as String]
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
    
    func insertImage(_ image: UIImage, withAssetURL assetURL: URL? = nil) {
        // Inserting the image changes our font and text color, so save those now and restore those later.
        let font = textView.font
        let textColor = textView.textColor
        
        let attachment = TextAttachment(image: image, assetURL: assetURL)
        let string = NSAttributedString(attachment: attachment)
        // Directly modify the textStorage instead of setting a whole new attributedText on the UITextView, which can be slow and jumps the text view around. We'll need to post our own text changed notification too.
        textView.textStorage.replaceCharacters(in: textView.selectedRange, with: string)
        
        textView.font = font
        textView.textColor = textColor
        
        if let selection = textView.selectedTextRange {
            let afterImagePosition = textView.position(from: selection.end, offset: 1)
            textView.selectedTextRange = textView.textRange(from: afterImagePosition!, to: afterImagePosition!)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name.UITextViewTextDidChange, object: textView)
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let edited = info[UIImagePickerControllerEditedImage] as! UIImage? {
            // AssetsLibrary's thumbnailing only gives us the original image, so ignore the asset URL.
            insertImage(edited)
        } else {
            let original = info[UIImagePickerControllerOriginalImage] as! UIImage
            insertImage(original, withAssetURL: info[UIImagePickerControllerReferenceURL] as! URL?)
        }
        picker.dismiss(animated: true) {
            self.textView.becomeFirstResponder()
            return
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.textView.becomeFirstResponder()
            return
        }
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
        if UIPasteboard.general.awful_URL == nil {
            linkifySelection(tree)
        } else {
            tree.showSubmenu(URLItems)
        }
    }),
    MenuItem(title: "[img]", action: { $0.showSubmenu(imageItems) }),
    MenuItem(title: "Format", action: { $0.showSubmenu(formattingItems) }),
    MenuItem(title: "[video]", action: { tree in
        if let URL = UIPasteboard.general.awful_URL {
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
        if let URL = UIPasteboard.general.awful_URL {
            wrapSelectionInTag("[url=\(URL.absoluteString)]" as NSString)(tree)
        }
    })
]

fileprivate let imageItems = [
    MenuItem(title: "From Camera", action: { $0.showImagePicker(.camera) }, enabled: isPickerAvailable(.camera)),
    MenuItem(title: "From Library", action: { $0.showImagePicker(.photoLibrary) }, enabled: isPickerAvailable(.photoLibrary)),
    MenuItem(title: "[img]", action: wrapSelectionInTag("[img]")),
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
        if let
            copiedURL = UIPasteboard.general.awful_URL,
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
    case let (host?, path) where host.hasSuffix("youtu.be") && path.characters.count > 1:
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
        return NSLog("[\(#function)] error creating link data detector: \(error)")
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
            selectedRange.location += NSMaxRange(equalsPart) + 1
        } else {
            selectedRange.location += selectedRange.length + tagspec.length + closingTag.length
            selectedRange.length = 0
        }
        textView.selectedRange = selectedRange
        textView.becomeFirstResponder()
    }
}

fileprivate func isPickerAvailable(_ sourceType: UIImagePickerControllerSourceType) -> (Void) -> Bool {
    return {
        return UIImagePickerController.isSourceTypeAvailable(sourceType)
    }
}
