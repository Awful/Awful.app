//  PrivateMessageViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader
import Mustache

private let Log = Logger.get()

struct PrivateMessageViewModel: MustacheBoxable {
    private let dict: [String: Any]

    init(message: PrivateMessage, stylesheet: String?) {
        let showAvatars = AwfulSettings.shared().showAvatars
        let hiddenAvataruRL = showAvatars ? nil : message.from?.avatarURL
        var htmlContents: String? {
            guard let originalHTML = message.innerHTML else { return nil }
            let document = HTMLDocument(string: originalHTML)
            document.removeSpoilerStylingAndEvents()
            document.useHTML5VimeoPlayer()
            document.processImgTags(shouldLinkifyNonSmilies: !AwfulSettings.shared().showImages)
            return document.firstNode(matchingSelector: "body")?.innerHTML
        }
        var javascript: String? {
            var error: NSError?
            let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "private-message.js"], &error)
            if script == nil {
                Log.e("error loading JavaaScripts: \(error as Any)")
            }
            return script
        }
        let visibleAvatarURL = showAvatars ? message.from?.avatarURL : nil

        dict = [
            "fromUsername": message.fromUsername ?? "",
            "hiddenAvataruRL": hiddenAvataruRL as Any,
            "htmlContents": htmlContents as Any,
            "javascript": javascript as Any,
            "messageID": message.messageID,
            "regdate": message.from?.regdate as Any,
            "seen": message.seen,
            "sentDate": message.sentDate as Any,
            "showAvatars": showAvatars,
            "stylesheet": stylesheet as Any,
            "visibleAvatarURL": visibleAvatarURL as Any]
    }

    var mustacheBox: MustacheBox {
        return Box(dict)
    }
}
