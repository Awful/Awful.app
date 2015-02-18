//  CompositionMenuTree.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Can take over UIMenuController to show a tree of composition-related items on behalf of a text view.
// This classes exists to expose the struct-defined menu to Objective-C and to act as an image picker delegate.
final class CompositionMenuTree: NSObject {
    private let textView: UITextView
    
    /// The textView's class will have some responder chain methods swizzled.
    init(textView: UITextView) {
        self.textView = textView
        super.init()
        
        PSMenuItem.installMenuHandlerForObject(textView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textViewDidBeginEditing:", name: UITextViewTextDidBeginEditingNotification, object: textView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textViewDidEndEditing:", name: UITextViewTextDidEndEditingNotification, object: textView)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func textViewDidBeginEditing(note: NSNotification) {
        popToRootItems()
    }
    
    @objc private func textViewDidEndEditing(note: NSNotification) {
        UIMenuController.sharedMenuController().menuItems = nil
    }
    
    private func startObservingMenuDidHide() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "menuDidHide:", name: UIMenuControllerDidHideMenuNotification, object: nil)
    }
    
    private func stopObservingMenuDidHide() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIMenuControllerDidHideMenuNotification, object: nil)
    }
    
    @objc private func menuDidHide(note: NSNotification) {
        popToRootItems()
    }
    
    private var selectedTextViewRect: CGRect {
        let fallback = textView.bounds
        if let selection = textView.selectedTextRange {
            return (textView.selectionRectsForRange(selection) as! [UITextSelectionRect])
                .map { $0.rect }
                .reduce { CGRectUnion($0, $1) }
                ?? fallback
        } else {
            return fallback
        }
    }
    
    private func popToRootItems() {
        UIMenuController.sharedMenuController().menuItems = psItemsForMenuItems(rootItems)
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = false
    }
    
    private func showSubmenu(submenu: [MenuItem]) {
        stopObservingMenuDidHide()
        
        UIMenuController.sharedMenuController().menuItems = psItemsForMenuItems(submenu)
        // Simply calling UIMenuController.update() here doesn't suffice; the menu simply hides. Instead we need to hide the menu then show it again.
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = true
        UIMenuController.sharedMenuController().menuVisible = false
        if let selection = textView.selectedTextRange {
            UIMenuController.sharedMenuController().setTargetRect(selectedTextViewRect, inView: textView)
        }
        UIMenuController.sharedMenuController().setMenuVisible(true, animated: true)
        
        startObservingMenuDidHide()
    }
    
    private func showImagePicker(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = [kUTTypeImage]
        picker.allowsEditing = false
        picker.delegate = self
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad && sourceType == .PhotoLibrary {
            picker.modalPresentationStyle = .Popover
            if let popover = picker.popoverPresentationController {
                popover.sourceRect = selectedTextViewRect
                popover.sourceView = textView
                popover.delegate = self
            }
        }
        textView.awful_viewController.presentViewController(picker, animated: true, completion: nil)
    }
    
    private func insertImage(image: UIImage, withAssetURL assetURL: NSURL? = nil) {
        // Inserting the image changes our font and text color, so save those now and restore those later.
        let font = textView.font
        let textColor = textView.textColor
        
        let attachment = AwfulTextAttachment(image: image, assetURL: assetURL)
        let string = NSAttributedString(attachment: attachment)
        // Directly modify the textStorage instead of setting a whole new attributedText on the UITextView, which can be slow and jumps the text view around. We'll need to post our own text changed notification too.
        textView.textStorage.replaceCharactersInRange(textView.selectedRange, withAttributedString: string)
        
        textView.font = font
        textView.textColor = textColor
        
        if let selection = textView.selectedTextRange {
            let afterImagePosition = textView.positionFromPosition(selection.end, offset: 1)
            textView.selectedTextRange = textView.textRangeFromPosition(afterImagePosition, toPosition: afterImagePosition)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(UITextViewTextDidChangeNotification, object: textView)
    }
    
    private func psItemsForMenuItems(items: [MenuItem]) -> [PSMenuItem] {
        return items.filter { $0.enabled() }
            .map { item in PSMenuItem(title: item.title) { item.action(self) } }
    }
}

extension CompositionMenuTree: UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        if viewController == (navigationController.viewControllers as! [UIViewController]).first {
            viewController.navigationItem.title = "Insert Image"
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let edited = info[UIImagePickerControllerEditedImage] as! UIImage? {
            // AssetsLibrary's thumbnailing only gives us the original image, so ignore the asset URL.
            insertImage(edited)
        } else {
            let original = info[UIImagePickerControllerOriginalImage] as! UIImage
            insertImage(original, withAssetURL: (info[UIImagePickerControllerReferenceURL] as! NSURL))
        }
        picker.dismissViewControllerAnimated(true) {
            self.textView.becomeFirstResponder()
            return
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true) {
            self.textView.becomeFirstResponder()
            return
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        textView.becomeFirstResponder()
    }
}

@objc protocol CompositionHidesMenuItems {
    var hidesBuiltInMenuItems: Bool { get set }
}

private struct MenuItem {
    var title: String
    var action: CompositionMenuTree -> Void
    var enabled: () -> Bool
    
    init(title: String, action: CompositionMenuTree -> Void, enabled: () -> Bool) {
        self.title = title
        self.action = action
        self.enabled = enabled
    }
    
    init(title: String, action: CompositionMenuTree -> Void) {
        self.init(title: title, action: action, enabled: { true })
    }
    
    func psItem(tree: CompositionMenuTree) {
        return
    }
}

private let rootItems = [
    MenuItem(title: "[url]", action: { tree in
        if UIPasteboard.generalPasteboard().awful_URL == nil {
            linkifySelection(tree)
        } else {
            tree.showSubmenu(URLItems)
        }
    }),
    MenuItem(title: "[img]", action: { $0.showSubmenu(imageItems) }),
    MenuItem(title: "Format", action: { $0.showSubmenu(formattingItems) }),
    MenuItem(title: "[video]", action: { tree in
        if let URL = UIPasteboard.generalPasteboard().awful_URL {
            if videoURLIsTaggable(URL) {
                return tree.showSubmenu(videoSubmenuItems)
            }
        }
        wrapSelectionInTag("[video]")(tree: tree)
    })
]

private let URLItems = [
    MenuItem(title: "[url]", action: linkifySelection),
    MenuItem(title: "Paste", action: { tree in
        if let URL = UIPasteboard.generalPasteboard().awful_URL {
            wrapSelectionInTag("[url=\(URL.absoluteString!)]")(tree: tree)
        }
    })
]

private let imageItems = [
    MenuItem(title: "From Camera", action: { $0.showImagePicker(.Camera) }, enabled: isPickerAvailable(.Camera)),
    MenuItem(title: "From Library", action: { $0.showImagePicker(.PhotoLibrary) }, enabled: isPickerAvailable(.PhotoLibrary)),
    MenuItem(title: "[img]", action: wrapSelectionInTag("[img]")),
    MenuItem(title: "Paste", action: { tree in
        if let image = UIPasteboard.generalPasteboard().image {
            tree.insertImage(image)
        }
        }, enabled: { UIPasteboard.generalPasteboard().image != nil })
]

private let formattingItems = [
    MenuItem(title: "[b]", action: wrapSelectionInTag("[b]")),
    MenuItem(title: "[s]", action: wrapSelectionInTag("[s]")),
    MenuItem(title: "[u]", action: wrapSelectionInTag("[u]")),
    MenuItem(title: "[spoiler]", action: wrapSelectionInTag("[spoiler]")),
    MenuItem(title: "[fixed]", action: wrapSelectionInTag("[fixed]")),
    MenuItem(title: "[quote]", action: wrapSelectionInTag("[quote=]\n")),
    MenuItem(title: "[code]", action: wrapSelectionInTag("[code]\n")),
]

private let videoSubmenuItems = [
    MenuItem(title: "[video]", action: wrapSelectionInTag("[video]")),
    MenuItem(title: "Paste", action: { tree in
        if let URL = UIPasteboard.generalPasteboard().awful_URL {
            let textView = tree.textView
            if let selectedTextRange = textView.selectedTextRange {
                let tag = "[video]\(URL.absoluteString!)[/video]"
                let textView = tree.textView
                textView.replaceRange(selectedTextRange, withText: tag)
                textView.selectedRange = NSRange(location: textView.selectedRange.location + (tag as NSString).length, length: 0)
            }
        }
    })
]

private func videoURLIsTaggable(URL: NSURL) -> Bool {
    switch (URL.host?.lowercaseString, URL.path?.lowercaseString) {
    case let (.Some(host), .Some(path)) where host.hasSuffix("cnn.com") && path.hasPrefix("/video"): return true
    case let (.Some(host), .Some(path)) where host.hasSuffix("foxnews.com") && path.hasPrefix("/video"): return true
    case let (.Some(host), _) where host.hasSuffix("video.yahoo.com"): return true
    case let (.Some(host), _) where host.hasSuffix("vimeo.com"): return true
    case let (.Some(host), _) where host.hasSuffix("youtube.com"): return true
    default: return false
    }
}

private func linkifySelection(tree: CompositionMenuTree) {
    var error: NSError?
    let detector: NSDataDetector! = NSDataDetector(types: NSTextCheckingType.Link.rawValue, error: &error)
    if detector == nil {
        return NSLog("[%@] error creating link data detector: %@", __FUNCTION__, error!)
    }
    
    let textView = tree.textView
    if let selectionRange = textView.selectedTextRange {
        let selection: NSString = textView.textInRange(selectionRange)
        let matches = detector.matchesInString(selection as! String, options: nil, range: NSRange(location: 0, length: selection.length)) as! [NSTextCheckingResult]
        if let firstMatchLength = matches.first?.range.length {
            if firstMatchLength == selection.length && selection.length > 0 {
                return wrapSelectionInTag("[url]")(tree: tree)
            }
        }
    }
    
    wrapSelectionInTag("[url=]")(tree: tree)
}

/**
tagspec specifies which tag to insert, with optional newlines and attribute insertion. For example:

- [b] puts plain opening and closing tags around the selection.
- [code]\n does the above plus inserts a newline after the opening tag and before the closing tag.
- [quote=]\n does the above plus inserts an = sign within the opening tag and, after wrapping, places the cursor after it.
- [url=http://example.com] puts an opening and closing tag around the selection with the attribute intact in the opening tag and, after wrapping, places the cursor after the closing tag.
*/
private func wrapSelectionInTag(tagspec: NSString)(tree: CompositionMenuTree) {
    let textView = tree.textView
    
    var equalsPart = tagspec.rangeOfString("=")
    let end = tagspec.rangeOfString("]")
    if equalsPart.location != NSNotFound {
        equalsPart.length = end.location - equalsPart.location
    }
    
    let closingTag = NSMutableString(string: tagspec as! String)
    if equalsPart.location != NSNotFound {
        closingTag.deleteCharactersInRange(equalsPart)
    }
    closingTag.insertString("/", atIndex: 1)
    if tagspec.hasSuffix("\n") {
        closingTag.insertString("\n", atIndex: 0)
    }
    
    var selectedRange = textView.selectedRange
    
    if let selection = textView.selectedTextRange {
        textView.replaceRange(textView.textRangeFromPosition(selection.end, toPosition: selection.end), withText: closingTag as! String)
        textView.replaceRange(textView.textRangeFromPosition(selection.start, toPosition: selection.start), withText: tagspec as! String)
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

private func isPickerAvailable(sourceType: UIImagePickerControllerSourceType)() -> Bool {
    return UIImagePickerController.isSourceTypeAvailable(sourceType)
}
