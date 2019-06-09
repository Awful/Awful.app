//  WeakTrampoline.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app


import Foundation
import WebKit

/// `WKUserContentController` takes a strong reference to its script handlers. That makes a retain cycle when your script handler has a strong reference to the web view. The trampoline breaks the cycle.
final class ScriptMessageHandlerWeakTrampoline: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
