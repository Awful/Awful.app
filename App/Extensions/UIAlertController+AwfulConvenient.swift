//  UIAlertController+AwfulConvenient.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIAlertController {

    // MARK: Convenience initializers
    
    /// Creates an alert-style alert controller with a canned message derived from the error, and adds an OK button to dismiss the alert.
    convenience init(title: String, error: Error, handler: (() -> Void)? = nil) {
        let error = error as NSError
        let message = "\(error.localizedDescription) (code \(error.code))"
        self.init(title: title, message: message, handler: handler)
    }

    /// Creates an alert-style alert controller with a canned title/message derived from the network error, and adds an OK button to dismiss the alert.
    convenience init(networkError error: Error, handler: (() -> Void)? = nil) {
        self.init(title: "Network Error", error: error, handler: handler)
    }

    /// Creates an alert-style alert controller with an OK button to dismiss the alert.
    convenience init(title: String, message: String, handler: (() -> Void)? = nil) {
        self.init(title: title, message: message, preferredStyle: .alert)
        addAction(UIAlertAction(title: "OK", style: .default) { action in
            handler?()
        })
    }

    /// Creates an action sheet-style alert controller.
    class func makeActionSheet() -> UIAlertController {
        return self.init(title: nil, message: nil, preferredStyle: .actionSheet)
    }

    // MARK: Convenient actions

    func addActionWithTitle(_ title: String, handler: (() -> Void)?) {
        addAction(UIAlertAction(title: title, style: .default) { action in
            handler?()
        })
    }

    /// Adds an action titled "Cancel" of style cancel.
    func addCancelActionWithHandler(_ handler: (() -> Void)?) {
        addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            handler?()
        })
    }

    func addActions(_ actions: [UIAlertAction]) {
        for action in actions {
            addAction(action)
        }
    }
}

