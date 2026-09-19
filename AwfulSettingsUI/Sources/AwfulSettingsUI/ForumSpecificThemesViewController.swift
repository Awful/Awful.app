//  ForumSpecificThemesView.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import SwiftUI

/// Lists every forum that supports a custom theme. Each forum row group has
/// one entry per theme mode (light/dark) that navigates to a `ThemePickerView`
/// for that forum/mode pair.
struct ForumSpecificThemesView: View {

    @FetchRequest private var forums: FetchedResults<Forum>

    @AppStorage(Settings.defaultLightThemeName) private var defaultLightThemeName
    @AppStorage(Settings.defaultDarkThemeName) private var defaultDarkThemeName

    /// Changed only on a full data store reset, which invalidates the fetch request.
    @State private var refreshToken = UUID()

    init() {
        let request = Forum.makeFetchRequest()
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(Forum.forumID), Theme.forumsWithSpecificThemes)
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true),
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true),
        ]
        _forums = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        List {
            ForEach(forums, id: \.forumID) { forum in
                Section(forum.name ?? "") {
                    ForEach(Theme.Mode.allCases, id: \.self) { mode in
                        ForumThemeLink(
                            forumID: forum.forumID,
                            forumName: forum.name ?? "",
                            mode: mode,
                            defaultTheme: defaultTheme(mode: mode)
                        )
                    }
                }
            }
        }
        // A store reset invalidates the fetched forums, so rebuild the list from scratch.
        // Theme changes are not handled here: each row observes its own defaults key.
        .id(refreshToken)
        .onReceive(NotificationCenter.default.publisher(for: .dataStoreDidReset)) { _ in
            refreshToken = UUID()
        }
    }

    private func defaultTheme(mode: Theme.Mode) -> Theme {
        let name: BuiltInTheme = switch mode {
        case .light: defaultLightThemeName
        case .dark: defaultDarkThemeName
        }
        return Theme.theme(named: name.rawValue) ?? Theme.defaultTheme(mode: mode)
    }
}

/// One forum/mode row. It observes exactly the defaults key that holds this
/// forum's theme for this mode, so it updates itself when that theme changes
/// without the surrounding list losing its identity or scroll position.
private struct ForumThemeLink: View {
    let forumID: String
    let forumName: String
    let mode: Theme.Mode
    let defaultTheme: Theme

    @AppStorage private var themeName: String?

    init(forumID: String, forumName: String, mode: Theme.Mode, defaultTheme: Theme) {
        self.forumID = forumID
        self.forumName = forumName
        self.mode = mode
        self.defaultTheme = defaultTheme
        _themeName = AppStorage(Theme.defaultsKeyForForum(identifiedBy: forumID, mode: mode))
    }

    private var theme: Theme {
        themeName.flatMap(Theme.theme(named:)) ?? defaultTheme
    }

    var body: some View {
        NavigationLink {
            ThemePickerView(forumID: forumID, mode: mode)
                .navigationTitle("\(forumName) \(mode.localizedDescription)")
        } label: {
            HStack {
                Text(mode.localizedDescription)
                Spacer()
                Text(theme.descriptiveName)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
