//  KeyboardShortcutsView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI

/// A group of shortcuts on the reference screen, e.g. "Reading a Thread".
public struct KeyboardShortcutSection: Identifiable {
    public var id: String { title }
    public let title: String
    public let shortcuts: [KeyboardShortcutRow]

    public init(title: String, shortcuts: [KeyboardShortcutRow]) {
        self.title = title
        self.shortcuts = shortcuts
    }
}

/// One shortcut on the reference screen: what it does and the keys that do it, already spelled out (e.g. "⇧⌘R").
public struct KeyboardShortcutRow: Identifiable {
    public var id: String { title + keys }
    public let title: String
    public let keys: String

    public init(title: String, keys: String) {
        self.title = title
        self.keys = keys
    }
}

/// Lists the app's hardware keyboard shortcuts. The app supplies the rows; this only lays them out.
public struct KeyboardShortcutsView: View {
    let sections: [KeyboardShortcutSection]
    @Environment(\.theme) var theme

    public init(sections: [KeyboardShortcutSection]) {
        self.sections = sections
    }

    public var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.shortcuts) { shortcut in
                        HStack(alignment: .firstTextBaseline) {
                            Text(shortcut.title)
                                .foregroundStyle(theme[color: "listText"]!)
                            Spacer(minLength: 16)
                            Text(shortcut.keys)
                                .font(.body.monospaced())
                                .foregroundStyle(theme[color: "listSecondaryText"]!)
                                .multilineTextAlignment(.trailing)
                        }
                        .listRowBackground(theme[color: "listBackground"])
                    }
                } header: {
                    Text(section.title)
                        .foregroundStyle(theme[color: "listSecondaryText"]!)
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Shortcuts need a hardware keyboard. On iPad, hold ⌘ to see the shortcuts for the screen you're on.", bundle: .module)
                    .foregroundStyle(theme[color: "listSecondaryText"]!)
            }
        }
        .listStyle(.grouped)
        .backport.scrollContentBackground(.hidden)
        .background(theme[color: "background"]!)
        .tint(theme[color: "tint"]!)
    }
}

#Preview {
    KeyboardShortcutsView(sections: [
        KeyboardShortcutSection(title: "General", shortcuts: [
            KeyboardShortcutRow(title: "Refresh the thread or list you're reading", keys: "⌘R"),
            KeyboardShortcutRow(title: "Refresh the sidebar list", keys: "⇧⌘R"),
        ]),
    ])
}
