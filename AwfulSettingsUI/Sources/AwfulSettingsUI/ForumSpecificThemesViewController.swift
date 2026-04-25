//  ForumSpecificThemesView.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulTheming
import CoreData
import SwiftUI

/// Lists every forum that supports a custom theme. Each forum row group has
/// one entry per theme mode (light/dark) that navigates to a `ThemePickerView`
/// for that forum/mode pair.
struct ForumSpecificThemesView: View {

    @Environment(\.managedObjectContext) private var managedObjectContext

    @FetchRequest private var forums: FetchedResults<Forum>
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
                        let theme = Theme.currentTheme(for: ForumID(forum.forumID), mode: mode)
                        NavigationLink {
                            ThemePickerView(forumID: forum.forumID, mode: mode)
                                .navigationTitle("\(forum.name ?? "") \(mode.localizedDescription)")
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
            }
        }
        .id(refreshToken)
        .onReceive(NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)) { _ in
            refreshToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataStoreDidReset)) { _ in
            refreshToken = UUID()
        }
    }
}
