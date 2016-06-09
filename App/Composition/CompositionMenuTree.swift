//  CompositionMenuTree.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PSMenuItem
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
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(UITextViewDelegate.textViewDidBeginEditing(_:)), name: UITextViewTextDidBeginEditingNotification, object: textView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(UITextViewDelegate.textViewDidEndEditing(_:)), name: UITextViewTextDidEndEditingNotification, object: textView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CompositionMenuTree.menuDidHide(_:)), name: UIMenuControllerDidHideMenuNotification, object: nil)
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
    
    @objc private func menuDidHide(note: NSNotification) {
        if shouldPopWhenMenuHides && textView.window != nil {
            popToRootItems()
        }
    }
    
    private var shouldPopWhenMenuHides = true
    
    private var targetRect: CGRect {
        return textView.selectedRect ?? textView.bounds
    }
    
    private func popToRootItems() {
        UIMenuController.sharedMenuController().menuItems = psItemsForMenuItems(rootItems)
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = false
    }
    
    private func showSubmenu(submenu: [MenuItem]) {
        shouldPopWhenMenuHides = false
        
        UIMenuController.sharedMenuController().menuItems = psItemsForMenuItems(submenu)
        // Simply calling UIMenuController.update() here doesn't suffice; the menu simply hides. Instead we need to hide the menu then show it again.
        (textView as? CompositionHidesMenuItems)?.hidesBuiltInMenuItems = true
        UIMenuController.sharedMenuController().menuVisible = false
        if let _ = textView.selectedTextRange {
            UIMenuController.sharedMenuController().setTargetRect(targetRect, inView: textView)
        }
        UIMenuController.sharedMenuController().setMenuVisible(true, animated: true)
        
        shouldPopWhenMenuHides = true
    }
    
    private func showImagePicker(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        let mediaType : NSString = kUTTypeImage as NSString
        picker.mediaTypes = [mediaType as String]
        picker.allowsEditing = false
        picker.delegate = self
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad && sourceType == .PhotoLibrary {
            picker.modalPresentationStyle = .Popover
            if let popover = picker.popoverPresentationController {
                popover.sourceRect = targetRect
                popover.sourceView = textView
                popover.delegate = self
            }
        }
        textView.nearestViewController?.presentViewController(picker, animated: true, completion: nil)
    }
    
    private func insertImage(image: UIImage, withAssetURL assetURL: NSURL? = nil) {
        // Inserting the image changes our font and text color, so save those now and restore those later.
        let font = textView.font
        let textColor = textView.textColor
        
        let attachment = TextAttachment(image: image, assetURL: assetURL)
        let string = NSAttributedString(attachment: attachment)
        // Directly modify the textStorage instead of setting a whole new attributedText on the UITextView, which can be slow and jumps the text view around. We'll need to post our own text changed notification too.
        textView.textStorage.replaceCharactersInRange(textView.selectedRange, withAttributedString: string)
        
        textView.font = font
        textView.textColor = textColor
        
        if let selection = textView.selectedTextRange {
            let afterImagePosition = textView.positionFromPosition(selection.end, offset: 1)
            textView.selectedTextRange = textView.textRangeFromPosition(afterImagePosition!, toPosition: afterImagePosition!)
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
        if viewController == navigationController.viewControllers.first {
            viewController.navigationItem.title = "Insert Image"
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let edited = info[UIImagePickerControllerEditedImage] as! UIImage? {
            // AssetsLibrary's thumbnailing only gives us the original image, so ignore the asset URL.
            insertImage(edited)
        } else {
            let original = info[UIImagePickerControllerOriginalImage] as! UIImage
            insertImage(original, withAssetURL: info[UIImagePickerControllerReferenceURL] as! NSURL?)
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
            if videoTagURLForURL(URL) != nil {
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
            wrapSelectionInTag("[url=\(URL.absoluteString)]")(tree: tree)
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
    MenuItem(title: "[i]", action: wrapSelectionInTag("[i]")),
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
        if let
            copiedURL = UIPasteboard.generalPasteboard().awful_URL,
            URL = videoTagURLForURL(copiedURL)
        {
            let textView = tree.textView
            if let selectedTextRange = textView.selectedTextRange {
                let tag = "[video]\(URL.absoluteString)[/video]"
                let textView = tree.textView
                textView.replaceRange(selectedTextRange, withText: tag)
                textView.selectedRange = NSRange(location: textView.selectedRange.location + (tag as NSString).length, length: 0)
            }
        }
    })
]

private func videoTagURLForURL(URL: NSURL) -> NSURL? {
    switch (URL.host?.lowercaseString, URL.path?.lowercaseString) {
    case let (.Some(host), .Some(path)) where host.hasSuffix("cnn.com") && path.hasPrefix("/video"):
        return URL
    case let (.Some(host), .Some(path)) where host.hasSuffix("foxnews.com") && path.hasPrefix("/video"):
        return URL
    case let (.Some(host), _) where host.hasSuffix("video.yahoo.com"):
        return URL
    case let (.Some(host), _) where host.hasSuffix("vimeo.com"):
        return URL
    case let (.Some(host), .Some(path)) where host.hasSuffix("youtube.com") && path.hasPrefix("/watch"):
        return URL
    case let (.Some(host), .Some(path)) where host.hasSuffix("youtu.be") && path.characters.count > 1:
        if let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true) {
            let videoID = URL.pathComponents![1] 
            components.host = "www.youtube.com"
            components.path = "/watch"
            var queryItems = components.queryItems ?? []
            queryItems.insert(NSURLQueryItem(name: "v", value: videoID), atIndex: 0)
            components.queryItems = queryItems
            return components.URL
        }
        return nil
    default:
        return nil
    }
}

private func linkifySelection(tree: CompositionMenuTree) {
    var detector : NSDataDetector = NSDataDetector()
    do {
        detector = try NSDataDetector(types: NSTextCheckingType.Link.rawValue)
    }
    catch {
        return NSLog("[\(#function)] error creating link data detector: \(error)")
    }
    
    let textView = tree.textView
    if let selectionRange = textView.selectedTextRange {
        let selection: NSString = textView.textInRange(selectionRange)!
        let matches = detector.matchesInString(selection as String, options: [], range: NSRange(location: 0, length: selection.length))
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
private func wrapSelectionInTag(tagspec: NSString) -> (tree: CompositionMenuTree) -> Void {
    return { tree in
        let textView = tree.textView
        
        var equalsPart = tagspec.rangeOfString("=")
        let end = tagspec.rangeOfString("]")
        if equalsPart.location != NSNotFound {
            equalsPart.length = end.location - equalsPart.location
        }
        
        let closingTag = NSMutableString(string: tagspec)
        if equalsPart.location != NSNotFound {
            closingTag.deleteCharactersInRange(equalsPart)
        }
        closingTag.insertString("/", atIndex: 1)
        if tagspec.hasSuffix("\n") {
            closingTag.insertString("\n", atIndex: 0)
        }
        
        var selectedRange = textView.selectedRange
        
        if let selection = textView.selectedTextRange {
            textView.replaceRange(textView.textRangeFromPosition(selection.end, toPosition: selection.end)!, withText: closingTag as String)
            textView.replaceRange(textView.textRangeFromPosition(selection.start, toPosition: selection.start)!, withText: tagspec as String)
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

private func isPickerAvailable(sourceType: UIImagePickerControllerSourceType) -> Void -> Bool {
    return {
        return UIImagePickerController.isSourceTypeAvailable(sourceType)
    }
}
