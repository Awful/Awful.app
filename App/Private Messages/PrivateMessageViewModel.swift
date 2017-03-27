//  PrivateMessageViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

final class PrivateMessageViewModel: NSObject {
    fileprivate let privateMessage: PrivateMessage
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init()
    }
    
    @NSCopying var stylesheet: NSString?
    
    var userInterfaceIdiom: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "ipad"
        default: return "iphone"
        }
    }
    
    var visibleAvatarURL: URL? {
        return showAvatars ? privateMessage.from?.avatarURL as URL? : nil
    }
    
    var hiddenAvataruRL: URL? {
        return showAvatars ? nil : privateMessage.from?.avatarURL as URL?
    }
    
    var fromUsername: String {
        return privateMessage.fromUsername ?? ""
    }
    
    var showAvatars: Bool {
        return AwfulSettings.shared().showAvatars
    }
    
    var HTMLContents: String? {
        guard let originalHTML = privateMessage.innerHTML else { return nil }
        let document = HTMLDocument(string: originalHTML)
        RemoveSpoilerStylingAndEvents(document)
        UseHTML5VimeoPlayer(document)
        ProcessImgTags(document, !AwfulSettings.shared().showImages)
        return document.firstNode(matchingSelector: "body")?.innerHTML
    }
    
    var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter()
    }
    
    var sentDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter()
    }
    
    var javascript: String? {
        var error: NSError?
        let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "private-message.js"], &error)
        if script == nil {
            print("\(#function) error loading scripts: \(String(describing: error))")
        }
        return script
    }
    
    var fontScalePercentage: NSNumber? {
        let percentage = floor(AwfulSettings.shared().fontScale)
        if percentage == 100 { return nil }
        return percentage as NSNumber?
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
    
    var sentDate: Date? {
        return privateMessage.sentDate as Date?
    }
}
