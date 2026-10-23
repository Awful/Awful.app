//  MRProgressOverlayView+Confirmation.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import MRProgress
import UIKit

extension MRProgressOverlayView {

    /// How long a checkmark stays up before dismissing itself.
    private static let confirmationDuration: TimeInterval = 0.7

    /// Flashes a checkmark with `title` over the view, the way "Copied post!" does. The tint follows the presenter's theme when it has one.
    @MainActor
    static func flashConfirmation(_ title: String, in view: UIView, from presenter: UIViewController) {
        guard let overlay = showOverlayAdded(to: view, title: title, mode: .checkmark, animated: true) else { return }
        overlay.tintColor = tintColor(for: presenter)
        Task {
            try? await Task.sleep(timeInterval: confirmationDuration)
            overlay.dismiss(true)
        }
    }

    /// Shows a spinner with `title` while `work` runs, then flashes a checkmark with `completedTitle`. If `work` throws, the overlay disappears at once and the error propagates.
    @MainActor
    static func showProgress(_ title: String, completedTitle: String, in view: UIView, from presenter: UIViewController, while work: () async throws -> Void) async throws {
        guard let overlay = showOverlayAdded(to: view, title: title, mode: .indeterminate, animated: true) else {
            return try await work()
        }
        overlay.tintColor = tintColor(for: presenter)
        do {
            try await work()
        } catch {
            overlay.dismiss(false)
            throw error
        }
        overlay.mode = .checkmark
        overlay.titleLabelText = completedTitle
        try? await Task.sleep(timeInterval: confirmationDuration)
        overlay.dismiss(true)
    }

    private static func tintColor(for presenter: UIViewController) -> UIColor? {
        ((presenter as? Themeable)?.theme ?? Theme.defaultTheme())["tintColor"]
    }
}
