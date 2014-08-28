//  UIAlertController+AwfulConvenient.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIAlertController {

    // MARK: Convenience initializers

    class func alertWithTitle(title: String, error: NSError, handler: (action: UIAlertAction!) -> Void) -> UIAlertController {
        return informationalAlertWithTitle(title, message: messageForError(error), handler: handler)
    }

    class func alertWithTitle(title: String, error: NSError) -> UIAlertController {
        return informationalAlertWithTitle(title, message: messageForError(error), handler: nil)
    }

    class func alertWithNetworkError(error: NSError) -> UIAlertController {
        return alertWithTitle("Network Error", error: error)
    }

    class func informationalAlertWithTitle(title: String, message: String, handler: ((action: UIAlertAction!) -> Void)!) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert);
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: handler))
        return alert
    }

    class func informationalAlertWithTitle(title: String, message: String) -> UIAlertController {
        return informationalAlertWithTitle(title, message: message, handler: nil)
    }

    class func actionSheet() -> UIAlertController {
        return self(title: nil, message: nil, preferredStyle: .ActionSheet)
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
