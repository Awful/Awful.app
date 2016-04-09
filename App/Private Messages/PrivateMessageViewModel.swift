//  PrivateMessageViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class PrivateMessageViewModel: NSObject {
    private let privateMessage: PrivateMessage
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init()
    }
    
    @NSCopying var stylesheet: NSString?
    
    var userInterfaceIdiom: String {
        switch UIDevice.currentDevice().userInterfaceIdiom {
        case .Pad: return "ipad"
        default: return "iphone"
        }
    }
    
    var visibleAvatarURL: NSURL? {
        return showAvatars ? privateMessage.from?.avatarURL : nil
    }
    
    var hiddenAvataruRL: NSURL? {
        return showAvatars ? nil : privateMessage.from?.avatarURL
    }
    
    var fromUsername: String {
        return privateMessage.fromUsername ?? ""
    }
    
    var showAvatars: Bool {
        return AwfulSettings.sharedSettings().showAvatars
    }
    
    var HTMLContents: String? {
        guard let originalHTML = privateMessage.innerHTML else { return nil }
        let document = HTMLDocument(string: originalHTML)
        RemoveSpoilerStylingAndEvents(document)
        UseHTML5VimeoPlayer(document)
        ProcessImgTags(document, !AwfulSettings.sharedSettings().showImages)
        return document.firstNodeMatchingSelector("body")?.innerHTML
    }
    
    var regDateFormat: NSDateFormatter {
        return NSDateFormatter.regDateFormatter()
    }
    
    var sentDateFormat: NSDateFormatter {
        return NSDateFormatter.postDateFormatter()
    }
    
    var javascript: String? {
        var error: NSError?
        let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "private-message.js"], &error)
        if script == nil {
            print("\(#function) error loading scripts: %@", error)
        }
        return script
    }
    
    var fontScalePercentage: NSNumber? {
        let percentage = floor(AwfulSettings.sharedSettings().fontScale)
        if percentage == 100 { return nil }
        return percentage
    }
    
    var from: User? {
        return privateMessage.from
    }
    
    var messageID: String {
        return privateMessage.messageID
    }
    
    var seen: Bool {
        return privateMessage.seen
    }
    
    var sentDate: NSDate? {
        return privateMessage.sentDate
    }
}
