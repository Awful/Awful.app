//  GlossaryHostingController.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

/// Hosts the SAclopedia (SwiftUI) browser inside the UIKit app. Present this modally, e.g. from the
/// Forums screen's toolbar button. Mirrors the app's `SearchHostingController` so the presented sheet
/// keeps the app's theme and status-bar style.
public final class GlossaryHostingController: UIHostingController<AnyView> {

    public init() {
        super.init(rootView: AnyView(EmptyView()))
        rootView = AnyView(
            GlossaryRootView(onExit: { [weak self] in
                self?.dismiss(animated: true)
            })
            .themed()
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Control status bar appearance so it stays consistent with the app's theme while presented.
        modalPresentationCapturesStatusBarAppearance = true
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = Theme.defaultTheme()
        return (theme["statusBarBackground"] == "light") ? .darkContent : .lightContent
    }

    // Use this controller's status bar style instead of deferring to the child SwiftUI navigation controller.
    public override var childForStatusBarStyle: UIViewController? { nil }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
}
