//  UIAlertAction+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UIAlertAction {
    /// Creates a `cancel` action. The title defaults to a localized `"Cancel"`.
    class func cancel(
        title: String? = nil,
        handler: @escaping () -> Void = {}
    ) -> UIAlertAction {
        .init(
            title: title ?? String(localized: "Cancel", bundle: .module),
            style: .cancel,
            handler: { _ in handler() }
        )
    }

    /// Creates a `default` action.
    class func `default`(
        title: String,
        handler: @escaping () -> Void = {}
    ) -> UIAlertAction {
        .init(title: title, style: .default, handler: { _ in handler() })
    }

    /// Creates a `destructive` action.
    class func destructive(
        title: String,
        handler: @escaping () -> Void
    ) -> UIAlertAction {
        .init(title: title, style: .destructive, handler: { _ in handler() })
    }

    /// Creates a `default` action with title set to a localized `"OK"`.
    class func ok(
        handler: @escaping () -> Void = {}
    ) -> UIAlertAction {
        .init(
            title: String(localized: "OK", bundle: .module),
            style: .default,
            handler: { _ in handler() }
        )
    }
}
