//  UIAlertController+AwfulConvenient.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIAlertController {

    // MARK: Convenience initializers
    
    convenience init(title: String, error: NSError, handler: ((action: UIAlertAction!) -> Void)!) {
        self.init(title: title, message: messageForError(error), handler: handler)
    }

    convenience init(title: String, error: NSError) {
        self.init(title: title, message: messageForError(error))
    }
    
    class func alertWithTitle(title: String, error: NSError) -> UIAlertController {
        return UIAlertController(title: title, error: error)
    }

    convenience init(networkError error: NSError, handler: ((action: UIAlertAction!) -> Void)!) {
        self.init(title: "Network Error", error: error, handler: handler)
    }
    
    class func alertWithNetworkError(error: NSError) -> UIAlertController {
        return UIAlertController(networkError: error, handler: nil)
    }

    @objc(initAlertWithTitle:message:handler:)
    convenience init(title: String, message: String, handler: ((action: UIAlertAction!) -> Void)!) {
        self.init(title: title, message: message, preferredStyle: .Alert)
        addAction(UIAlertAction(title: "OK", style: .Default, handler: handler))
    }

    @objc(initAlertWithTitle:message:)
    convenience init(title: String, message: String) {
        self.init(title: title, message: message, handler: nil)
    }

    class func actionSheet() -> UIAlertController {
        return self.init(title: nil, message: nil, preferredStyle: .ActionSheet)
    }

    // MARK: Convenient actions

    func addActionWithTitle(title: String, handler: (() -> Void)!) {
        addAction(UIAlertAction(title: title, style: .Default) { _ in
            if handler != nil { handler() } })
    }

    func addCancelActionWithHandler(handler: (() -> Void)!) {
        addAction(UIAlertAction(title: "Cancel", style: .Cancel) { _ in
            if handler != nil { handler() } })
    }

    func addActions(actions: [UIAlertAction]) {
        for action in actions {
            addAction(action)
        }
    }
}

private func messageForError(error: NSError) -> String {
    return "\(error.localizedDescription) (code \(error.code))"
}
