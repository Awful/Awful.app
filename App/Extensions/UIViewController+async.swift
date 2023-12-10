//  UIViewController+async.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIViewController {
    /// Dismisses the view controller that was presented modally by the view controller.
    func dismiss(
        animated: Bool
    ) async {
        await withCheckedContinuation { continuation in
            dismiss(animated: animated) {
                continuation.resume()
            }
        }
    }
}
