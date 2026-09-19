//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: HostingController<PostsPageSettingsView>, UIPopoverPresentationControllerDelegate {

    /// Set by the presenter; called when the user taps "Set Zero Point" so the
    /// tilt scroll manager adopts the device's current pose as neutral.
    var tiltScrollRecalibrate: (() -> Void)?

    init() {
        // Allows indirect passing of `self` into root view actions before super.init().
        class UnownedBox {
            unowned var contents: PostsPageSettingsViewController!
        }
        let box = UnownedBox()

        super.init(rootView: PostsPageSettingsView(
            dismiss: { box.contents.dismiss(animated: true) },
            recalibrateTiltScroll: { box.contents.tiltScrollRecalibrate?() }
        ))
        box.contents = self

        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self

        if #available(iOS 16.0, *) {
            sizingOptions = .preferredContentSize
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Before iOS 16 there's no automatic `preferredContentSize`; ask the hosted view for its ideal size at the fixed width.
        if #unavailable(iOS 16.0) {
            preferredContentSize = sizeThatFits(in: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        view.tintColor = theme["tintColor"]
        view.backgroundColor = theme["sheetBackgroundColor"]
        popoverPresentationController?.backgroundColor = theme["sheetBackgroundColor"]
    }

    // MARK: UIAdaptivePresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
