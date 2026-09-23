//  AppDelegate+KeyCommands.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
 App-wide keyboard shortcuts, and the menu bar they appear in on iPad and Mac.

 They live on the app delegate because it ends every responder chain: whichever column of the iPad split view holds first responder (or nothing does), these still fire. Screen-specific shortcuts stay on their view controllers (see `PostsPageViewController.keyCommands`), and no unmodified key is registered here, so typing in a composer or search field is never intercepted.
 */
extension AppDelegate {

    /// iPhone only: iPad and Mac get these from the menu bar (`buildMenu(with:)`).
    override var keyCommands: [UIKeyCommand]? {
        guard !KeyboardShortcut.usesMainMenu,
              let stack = rootViewControllerStackIfLoaded, stack.canHandleKeyCommands
        else { return nil }

        var commands = [Self.refreshFocusedContentCommand, Self.refreshSidebarCommand]
        commands += Self.selectTabCommands(titles: stack.sidebarTabTitles)
        if stack.hasSettingsTab {
            commands.append(Self.selectSettingsTabCommand)
        }
        if stack.canToggleSidebar {
            commands.append(Self.toggleSidebarCommand(title: Self.toggleSidebarTitle(for: stack)))
        }
        commands.append(Self.showKeyboardShortcutsCommand)
        return commands
    }

    /**
     Puts every modified shortcut in the menu bar: the app-wide ones here, the thread ones from `PostsPageViewController.mainMenuCommands`.

     The menu is built once, so `RootViewControllerStack` asks for a rebuild when the sidebar tabs change. Whether an item is enabled is decided as the menu opens (or its key is pressed) by `canPerformAction(_:withSender:)` on whichever responder handles it, and state-dependent titles by `validate(_:)`.
     */
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main, KeyboardShortcut.usesMainMenu else { return }

        // Ours replaces the system's ⌃⌘S sidebar item, and there's no find here to lose, so Find Next's ⌘G can be Go to Page.
        builder.remove(menu: .sidebar)
        builder.remove(menu: .find)

        var goItems: [UIMenuElement] = Self.selectTabCommands(titles: rootViewControllerStackIfLoaded?.sidebarTabTitles ?? [])

        // A system menu that isn't there (older iPadOS doesn't build them all) shouldn't take its shortcuts with it, so they go in Go instead.
        func insert(_ commands: [UIKeyCommand], atStartOf parent: UIMenu.Identifier) {
            let menu = UIMenu(options: .displayInline, children: commands)
            if builder.menu(for: parent) != nil {
                builder.insertChild(menu, atStartOfMenu: parent)
            } else {
                goItems.append(menu)
            }
        }

        let settings = UIMenu(identifier: .preferences, options: .displayInline, children: [Self.selectSettingsTabCommand])
        if builder.menu(for: .preferences) != nil {
            builder.replace(menu: .preferences, with: settings)
        } else if builder.menu(for: .about) != nil {
            builder.insertSibling(settings, afterMenu: .about)
        } else {
            goItems.append(settings)
        }

        insert([Self.refreshFocusedContentCommand, Self.refreshSidebarCommand], atStartOf: .view)
        insert([Self.toggleSidebarCommand(title: nil)], atStartOf: .view)

        // ⇧⌘/ is the system Help item's ⌘?, and there's no help book, so the shortcuts sheet takes its place.
        let help = UIMenu(options: .displayInline, children: [Self.showKeyboardShortcutsCommand])
        if let helpMenu = builder.menu(for: .help) {
            builder.replace(menu: .help, with: helpMenu.replacingChildren([help]))
        } else {
            goItems.append(help)
        }

        let menus = [
            UIMenu(title: "Go", identifier: .awfulGo, children: goItems),
            UIMenu(title: "Thread", identifier: .awfulThread, children: PostsPageViewController.mainMenuCommands),
        ]
        if builder.menu(for: .view) != nil {
            for menu in menus.reversed() {
                builder.insertSibling(menu, afterMenu: .view)
            }
        } else if builder.menu(for: .window) != nil {
            for menu in menus {
                builder.insertSibling(menu, beforeMenu: .window)
            }
        } else if let root = builder.menu(for: .root) {
            builder.replace(menu: .root, with: root.replacingChildren(root.children + menus))
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(refreshFocusedContent(_:)),
             #selector(refreshSidebar(_:)),
             #selector(selectSidebarTab(_:)),
             #selector(showKeyboardShortcuts(_:)):
            return rootViewControllerStackIfLoaded?.canHandleKeyCommands ?? false
        case #selector(selectSettingsTab(_:)):
            guard let stack = rootViewControllerStackIfLoaded else { return false }
            return stack.canHandleKeyCommands && stack.hasSettingsTab
        case #selector(toggleSidebarFromKeyboard(_:)):
            guard let stack = rootViewControllerStackIfLoaded else { return false }
            return stack.canHandleKeyCommands && stack.canToggleSidebar
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    /// Focus is often in the sidebar while a thread is on screen, and the thread isn't in that responder chain. The chain ends here, so thread actions nothing else took go to the visible thread; that's what lights up the Thread menu.
    override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if PostsPageViewController.isShortcutAction(action),
           let stack = rootViewControllerStackIfLoaded, stack.canHandleKeyCommands,
           let postsPage = stack.visiblePostsPageViewController,
           postsPage.canPerformAction(action, withSender: sender)
        {
            return postsPage
        }
        return super.target(forAction: action, withSender: sender)
    }

    override func validate(_ command: UICommand) {
        super.validate(command)
        if command.action == #selector(toggleSidebarFromKeyboard(_:)), let stack = rootViewControllerStackIfLoaded {
            let title = Self.toggleSidebarTitle(for: stack)
            command.title = title
            command.discoverabilityTitle = title
        }
    }

    // MARK: Commands

    private static var refreshFocusedContentCommand: UIKeyCommand {
        KeyboardShortcut.refreshFocusedContent.makeKeyCommand(action: #selector(refreshFocusedContent(_:)))
    }

    private static var refreshSidebarCommand: UIKeyCommand {
        KeyboardShortcut.refreshSidebar.makeKeyCommand(action: #selector(refreshSidebar(_:)))
    }

    private static func selectTabCommands(titles: [String]) -> [UIKeyCommand] {
        titles.enumerated().prefix(9).map { index, title in
            KeyboardShortcut.selectTab.makeKeyCommand(
                action: #selector(selectSidebarTab(_:)),
                input: "\(index + 1)",
                title: title,
                propertyList: index
            )
        }
    }

    private static var selectSettingsTabCommand: UIKeyCommand {
        KeyboardShortcut.selectSettingsTab.makeKeyCommand(action: #selector(selectSettingsTab(_:)))
    }

    private static func toggleSidebarCommand(title: String?) -> UIKeyCommand {
        KeyboardShortcut.toggleSidebar.makeKeyCommand(action: #selector(toggleSidebarFromKeyboard(_:)), title: title)
    }

    private static func toggleSidebarTitle(for stack: RootViewControllerStack) -> String {
        stack.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar"
    }

    private static var showKeyboardShortcutsCommand: UIKeyCommand {
        KeyboardShortcut.showKeyboardShortcuts.makeKeyCommand(action: #selector(showKeyboardShortcuts(_:)))
    }

    // MARK: Actions

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

private extension UIMenu.Identifier {
    static let awfulGo = UIMenu.Identifier("com.awfulapp.Awful.menu.go")
    static let awfulThread = UIMenu.Identifier("com.awfulapp.Awful.menu.thread")
}
