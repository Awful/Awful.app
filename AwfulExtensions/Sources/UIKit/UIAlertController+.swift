//  UIAlertController+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// MARK: Convenience

public extension UIAlertController {
    /// Creates an action sheet with the given actions.
    convenience init(
        title: String? = nil,
        message: String? = nil,
        actionSheetActions: [UIAlertAction]
    ) {
        self.init(title: title, message: message, preferredStyle: .actionSheet)
        actionSheetActions.forEach(addAction(_:))
    }

    /// Creates an alert with the given actions.
    convenience init(
        title: String? = nil,
        message: String? = nil,
        alertActions: [UIAlertAction]
    ) {
        self.init(title: title, message: message, preferredStyle: .alert)
        alertActions.forEach(addAction(_:))
    }
}

// MARK: Errors

public extension UIAlertController {
    /// Creates an alert-style alert controller with a canned message derived from the error, and adds an OK button to dismiss the alert.
    convenience init(
        title: String,
        error: Error,
        handler: @escaping () -> Void = {}
    ) {
        let error = error as NSError
        self.init(
            title: title,
            message: "\(error.localizedDescription) (code \(error.code))",
            alertActions: [.default(title: String(localized: "OK"), handler: handler)]
        )
    }

    /// Creates an alert-style alert controller with a canned title/message derived from the network error, and adds an OK button to dismiss the alert.
    convenience init(
        networkError error: Error,
        handler: @escaping () -> Void = {}
    ) {
        self.init(title: String(localized: "Network Error"), error: error, handler: handler)
    }
}
