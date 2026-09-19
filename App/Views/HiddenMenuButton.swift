//  HiddenMenuButton.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

/**
 An invisible button that we misuse to show a proper iOS context menu on tap (as opposed to long-press).

 Add it to the view that hosts the content the menu is about (a `RenderView`, say), then call `show(menu:from:)` with the rect the menu should anchor to. The button moves itself over that rect and fires its primary action, which is the menu.
 */
final class HiddenMenuButton: UIButton {
    init() {
        super.init(frame: .zero)
        alpha = 0
        showsMenuAsPrimaryAction = true

        if #available(iOS 16.0, *) {
            preferredMenuElementOrder = .fixed
        }

        updateInterfaceStyle()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func show(menu: UIMenu, from rect: CGRect) {
        frame = rect
        self.menu = menu

        updateInterfaceStyle()

        gestureRecognizers?.first { "\(type(of: $0))".contains("TouchDown") }?.touchesBegan([], with: .init())
    }

    func updateInterfaceStyle() {
        // Follow the theme's menuAppearance setting for menu appearance
        let menuAppearance = Theme.defaultTheme()[string: "menuAppearance"]
        overrideUserInterfaceStyle = menuAppearance == "light" ? .light : .dark
    }

    /// iOS 26 portals a Liquid Glass platter behind a menu's source view while the menu
    /// animates in. Our source view is an invisible rect sitting over the web view's post
    /// dots, so that platter shows up as a stray glass bead beside the menu. The button's own
    /// `alpha = 0` doesn't suppress it — the platter is drawn by the menu presentation, not by
    /// the button — so hand UIKit a preview with nothing in it instead.
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        emptyMenuPreview()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        emptyMenuPreview()
    }

    private func emptyMenuPreview() -> UITargetedPreview? {
        // Pre-26 there's no platter to hide, and `UITargetedPreview(view:)` requires a window.
        // nil in either case means "use the system default", i.e. today's behaviour.
        guard #available(iOS 26.0, *), window != nil else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(rect: .zero)
        parameters.shadowPath = UIBezierPath(rect: .zero)
        return UITargetedPreview(view: self, parameters: parameters)
    }
}
