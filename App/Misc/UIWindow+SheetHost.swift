//  UIWindow+SheetHost.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIWindow {
    /// The topmost view controller that can host a sheet. Alerts can't present sheets, so a topmost alert is dismissed first, and an in-progress presentation or dismissal is waited out (briefly).
    @MainActor
    func sheetHostViewController() async -> UIViewController? {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            guard let root = rootViewController else { return nil }
            let top = root.topmostPresentedViewController

            if let alert = top as? UIAlertController, let presenting = alert.presentingViewController {
                await withCheckedContinuation { continuation in
                    presenting.dismiss(animated: true) { continuation.resume() }
                }
                continue
            }

            let busy = top.isBeingPresented || top.isBeingDismissed || top.presentedViewController != nil
            if !busy { return top }
            try? await Task.sleep(nanoseconds: 250_000_000)
        } while Date() < deadline
        return nil
    }
}
