//  KeyboardShortcutsViewController.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettingsUI
import AwfulTheming
import SwiftUI
import UIKit

/// The Keyboard Shortcuts reference, presented as a sheet from ⌘? and from the posts page's settings popover. (The Settings tab pushes the same `KeyboardShortcutsView` itself.)
final class KeyboardShortcutsViewController: HostingController<KeyboardShortcutsScreen> {

    init() {
        super.init(rootView: KeyboardShortcutsScreen())
        title = "Keyboard Shortcuts"
        modalPresentationStyle = .formSheet
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [unowned self] _ in
            dismiss(animated: true)
        })
    }

    /// The sheet, wrapped in a navigation controller for the title and Done button.
    static func makeSheet() -> UIViewController {
        KeyboardShortcutsViewController().enclosingNavigationController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct KeyboardShortcutsScreen: View {
    var body: some View {
        KeyboardShortcutsView(sections: KeyboardShortcut.referenceSections)
            .themed()
    }
}
