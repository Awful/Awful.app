//  AppDelegate+KeyCommands.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
 App-wide keyboard shortcuts.

 They live on the app delegate because it ends every responder chain: whichever column of the iPad split view holds first responder (or nothing does), these still fire. Screen-specific shortcuts stay on their view controllers (see `PostsPageViewController.keyCommands`), and no unmodified key is registered here, so typing in a composer or search field is never intercepted.
 */
extension AppDelegate {

    override var keyCommands: [UIKeyCommand]? {
        guard let stack = rootViewControllerStackIfLoaded, stack.canHandleKeyCommands else { return nil }

        var commands: [UIKeyCommand] = [
            KeyboardShortcut.refreshFocusedContent.makeKeyCommand(action: #selector(refreshFocusedContent(_:))),
            KeyboardShortcut.refreshSidebar.makeKeyCommand(action: #selector(refreshSidebar(_:))),
        ]

        for (index, title) in stack.sidebarTabTitles.enumerated().prefix(9) {
            commands.append(KeyboardShortcut.selectTab.makeKeyCommand(
                action: #selector(selectSidebarTab(_:)),
                input: "\(index + 1)",
                title: title,
                propertyList: index
            ))
        }

        if stack.hasSettingsTab {
            commands.append(KeyboardShortcut.selectSettingsTab.makeKeyCommand(action: #selector(selectSettingsTab(_:))))
        }

        if stack.canToggleSidebar {
            commands.append(KeyboardShortcut.toggleSidebar.makeKeyCommand(
                action: #selector(toggleSidebarFromKeyboard(_:)),
                title: stack.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar"
            ))
        }

        commands.append(KeyboardShortcut.showKeyboardShortcuts.makeKeyCommand(action: #selector(showKeyboardShortcuts(_:))))

        return commands
    }

    @objc private func refreshFocusedContent(_ sender: UIKeyCommand) {
        rootViewControllerStackIfLoaded?.refreshFocusedContent()
    }

    @objc private func refreshSidebar(_ sender: UIKeyCommand) {
        rootViewControllerStackIfLoaded?.refreshSidebar()
    }

    @objc private func selectSidebarTab(_ sender: UIKeyCommand) {
        guard let index = sender.propertyList as? Int else { return }
        rootViewControllerStackIfLoaded?.selectSidebarTab(at: index)
    }

    @objc private func selectSettingsTab(_ sender: UIKeyCommand) {
        rootViewControllerStackIfLoaded?.selectSettingsTab()
    }

    // Not `toggleSidebar(_:)`: UIResponder already declares that selector as a standard action.
    @objc private func toggleSidebarFromKeyboard(_ sender: UIKeyCommand) {
        rootViewControllerStackIfLoaded?.toggleSidebar()
    }

    @objc private func showKeyboardShortcuts(_ sender: UIKeyCommand) {
        rootViewControllerStackIfLoaded?.presentKeyboardShortcuts()
    }
}
