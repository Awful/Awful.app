//  KeyboardShortcuts.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettingsUI
import UIKit

/// Every keyboard shortcut the app offers, in one place.
///
/// Key commands are built from here (`makeKeyCommand`) so the Keyboard Shortcuts reference
/// screen (`referenceSections`) can't drift from what the app actually responds to.
///
/// Where a command is registered depends on the platform. On iPad and Mac, modified shortcuts
/// (`isInMainMenu`) go in the menu bar (`AppDelegate.buildMenu(with:)`), and each responder decides
/// whether they're enabled with `canPerformAction(_:withSender:)`. Everything else, and everything
/// on iPhone, comes from `keyCommands`: the app-wide ones on `AppDelegate`, the thread ones on
/// `PostsPageViewController`.
enum KeyboardShortcut: CaseIterable {

    // General
    case refreshFocusedContent
    case refreshSidebar
    case showKeyboardShortcuts

    // Sidebar
    case selectTab
    case selectSettingsTab
    case toggleSidebar

    // Thread
    case scrollUp
    case scrollDown
    case pageUp
    case pageDown
    case scrollToTop
    case scrollToBottom
    case previousPage
    case nextPage
    case firstPage
    case lastPage
    case goToPage
    case toggleBookmark
    case newReply

    // Composer
    case cancelComposition

    enum Section: CaseIterable {
        case general, sidebar, thread, composer

        var title: String {
            switch self {
            case .general: return "General"
            case .sidebar: return "Sidebar"
            case .thread: return "Reading a Thread"
            case .composer: return "Writing a Reply"
            }
        }
    }

    var section: Section {
        switch self {
        case .refreshFocusedContent, .refreshSidebar, .showKeyboardShortcuts:
            return .general
        case .selectTab, .selectSettingsTab, .toggleSidebar:
            return .sidebar
        case .scrollUp, .scrollDown, .pageUp, .pageDown, .scrollToTop, .scrollToBottom,
             .previousPage, .nextPage, .firstPage, .lastPage, .goToPage, .toggleBookmark, .newReply:
            return .thread
        case .cancelComposition:
            return .composer
        }
    }

    /// The key, before modifiers. `selectTab` stands for the family ⌘1…⌘5; pass the digit to `makeKeyCommand`.
    var input: String {
        switch self {
        case .refreshFocusedContent, .refreshSidebar: return "R"
        case .showKeyboardShortcuts: return "/"
        case .selectTab: return "1"
        case .selectSettingsTab: return ","
        case .toggleSidebar: return "S"
        case .scrollUp, .scrollToTop: return UIKeyCommand.inputUpArrow
        case .scrollDown, .scrollToBottom: return UIKeyCommand.inputDownArrow
        case .pageUp, .pageDown: return " "
        case .previousPage, .firstPage: return "["
        case .nextPage, .lastPage: return "]"
        case .goToPage: return "G"
        case .toggleBookmark: return "D"
        case .newReply: return "N"
        case .cancelComposition: return UIKeyCommand.inputEscape
        }
    }

    var modifierFlags: UIKeyModifierFlags {
        switch self {
        case .refreshFocusedContent, .selectTab, .selectSettingsTab, .scrollToTop, .scrollToBottom,
             .previousPage, .nextPage, .goToPage, .toggleBookmark, .newReply:
            return .command
        case .refreshSidebar, .showKeyboardShortcuts:
            return [.command, .shift]
        case .toggleSidebar:
            return [.control, .command]
        case .firstPage, .lastPage:
            return [.alternate, .command]
        case .pageUp:
            return .shift
        case .scrollUp, .scrollDown, .pageDown, .cancelComposition:
            return []
        }
    }

    /// Whether the menu bar carries this shortcut (when there is one; see `usesMainMenu`).
    ///
    /// Unmodified keys stay out of it: a menu item bound to Space or an arrow would take that key from text fields on the Mac.
    var isInMainMenu: Bool {
        !modifierFlags.intersection([.command, .control]).isEmpty
    }

    /// iPad and Mac get a menu bar built from `UIMenuBuilder` (and on iPadOS 15+, the ⌘-hold overlay is built from it too), so shortcuts that are in it aren't also returned from `keyCommands`.
    static let usesMainMenu = UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isMacCatalystApp

    /// The default discoverability title. State-dependent commands (bookmarking, the sidebar toggle) pass a live title to `makeKeyCommand`.
    var title: String {
        switch self {
        case .refreshFocusedContent: return "Refresh"
        case .refreshSidebar: return "Refresh Sidebar"
        case .showKeyboardShortcuts: return "Keyboard Shortcuts"
        case .selectTab: return "Select Tab"
        case .selectSettingsTab: return "Settings"
        case .toggleSidebar: return "Show or Hide Sidebar"
        case .scrollUp: return "Up"
        case .scrollDown: return "Down"
        case .pageUp: return "Page Up"
        case .pageDown: return "Page Down"
        case .scrollToTop: return "Scroll to Top"
        case .scrollToBottom: return "Scroll to Bottom"
        case .previousPage: return "Previous Page"
        case .nextPage: return "Next Page"
        case .firstPage: return "First Page"
        case .lastPage: return "Last Page"
        case .goToPage: return "Go to Page…"
        case .toggleBookmark: return "Bookmark or Unbookmark Thread"
        case .newReply: return "New Reply"
        case .cancelComposition: return "Cancel"
        }
    }

    /// The wording used on the reference screen, where the same key may cover a few states.
    var referenceTitle: String {
        switch self {
        case .refreshFocusedContent: return "Refresh the detail pane (the thread or message you're reading)"
        case .refreshSidebar: return "Refresh the sidebar list"
        case .selectTab: return "Select sidebar tab (Forums, Bookmarks, …) and refresh it"
        case .selectSettingsTab: return "Open Settings"
        case .toggleSidebar: return "Show or hide the sidebar"
        case .scrollUp: return "Scroll up a little"
        case .scrollDown: return "Scroll down a little"
        case .toggleBookmark: return "Bookmark or unbookmark the thread"
        case .goToPage: return "Go to a page"
        case .cancelComposition: return "Cancel the reply"
        default: return title
        }
    }

    /// The keys as they'd be printed, e.g. "⇧⌘R" or "⌘1 – ⌘5".
    var displayKeys: String {
        if self == .selectTab {
            return "⌘1 – ⌘5"
        }
        return Self.displayKeys(input: input, modifierFlags: modifierFlags)
    }

    static func displayKeys(input: String, modifierFlags: UIKeyModifierFlags) -> String {
        var keys = ""
        if modifierFlags.contains(.control) { keys += "⌃" }
        if modifierFlags.contains(.alternate) { keys += "⌥" }
        if modifierFlags.contains(.shift) { keys += "⇧" }
        if modifierFlags.contains(.command) { keys += "⌘" }
        switch input {
        case UIKeyCommand.inputUpArrow: keys += "↑"
        case UIKeyCommand.inputDownArrow: keys += "↓"
        case UIKeyCommand.inputLeftArrow: keys += "←"
        case UIKeyCommand.inputRightArrow: keys += "→"
        case UIKeyCommand.inputEscape: keys += "Esc"
        case " ": keys += "Space"
        default: keys += input.uppercased()
        }
        return keys
    }

    /**
     Builds the key command for this shortcut.

     - Parameters:
        - action: A selector on a responder in the chain; UIKit finds the target.
        - input: Replaces the catalogued key, for the ⌘1…⌘5 tab family.
        - title: Replaces the catalogued discoverability title, for state-dependent wording.
        - propertyList: Carried on the command for the action to read (e.g. a tab index).
     */
    func makeKeyCommand(
        action: Selector,
        input: String? = nil,
        title: String? = nil,
        propertyList: Any? = nil
    ) -> UIKeyCommand {
        let command = UIKeyCommand(
            title: title ?? self.title,
            action: action,
            input: input ?? self.input,
            modifierFlags: modifierFlags,
            propertyList: propertyList
        )
        command.discoverabilityTitle = title ?? self.title
        return command
    }

    /// The whole catalogue as the reference screen shows it, grouped by section in declaration order.
    static var referenceSections: [KeyboardShortcutSection] {
        Section.allCases.map { section in
            KeyboardShortcutSection(
                title: section.title,
                shortcuts: allCases
                    .filter { $0.section == section }
                    .map { KeyboardShortcutRow(title: $0.referenceTitle, keys: $0.displayKeys) }
            )
        }
    }
}
