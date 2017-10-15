//  PrivateMessageViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader

final class PrivateMessageViewModel: NSObject {
    fileprivate let privateMessage: PrivateMessage
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init()
    }
    
    @NSCopying @objc var stylesheet: NSString?
    
    @objc var userInterfaceIdiom: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "ipad"
        default: return "iphone"
        }
    }
    
    @objc var visibleAvatarURL: URL? {
        return showAvatars ? privateMessage.from?.avatarURL as URL? : nil
    }
    
    @objc var hiddenAvataruRL: URL? {
        return showAvatars ? nil : privateMessage.from?.avatarURL as URL?
    }
    
    @objc var fromUsername: String {
        return privateMessage.fromUsername ?? ""
    }
    
    @objc var showAvatars: Bool {
        return AwfulSettings.shared().showAvatars
    }
    
    @objc var HTMLContents: String? {
        guard let originalHTML = privateMessage.innerHTML else { return nil }
        let document = HTMLDocument(string: originalHTML)
        document.removeSpoilerStylingAndEvents()
        document.useHTML5VimeoPlayer()
        document.processImgTags(shouldLinkifyNonSmilies: !AwfulSettings.shared().showImages)
        return document.firstNode(matchingSelector: "body")?.innerHTML
    }
    
    @objc var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter
    }
    
    @objc var sentDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter
    }
    
    @objc var javascript: String? {
        var error: NSError?
        let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "private-message.js"], &error)
        if script == nil {
            print("\(#function) error loading scripts: \(String(describing: error))")
        }
        return script
    }
    
    @objc var fontScalePercentage: NSNumber? {
        let percentage = floor(AwfulSettings.shared().fontScale)
        if percentage == 100 { return nil }
        return percentage as NSNumber?
    }
    
    @objc var from: User? {
        return privateMessage.from
    }
    
    @objc var messageID: String {
        return privateMessage.messageID
    }
    
    @objc var seen: Bool {
        return privateMessage.seen
    }
    
    @objc var sentDate: Date? {
        return privateMessage.sentDate as Date?
    }
}
