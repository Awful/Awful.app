//  SwiftUIForumSpecificThemesView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulTheming
import CoreData
import SwiftUI

struct SwiftUIForumSpecificThemesView: View {
    @State private var forums: [Forum] = []
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.theme) private var theme
    
    init() {
        // Initialization moved to onAppear to use proper context
    }
    
    var body: some View {
        List {
            ForEach(forums, id: \.objectID) { forum in
                ForumThemeSection(forum: forum)
            }
        }
        .listStyle(.grouped)
        .navigationTitle("Forum-Specific Themes", bundle: .module)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadForums()
        }
        .onReceive(NotificationCenter.default.publisher(for: Theme.themeForForumDidChangeNotification)) { _ in
            loadForums() // Refresh when themes change
        }
    }
    
    private func loadForums() {
        print("🔍 loadForums called")
        print("🔍 managedObjectContext: \(managedObjectContext)")
        print("🔍 persistentStoreCoordinator: \(managedObjectContext.persistentStoreCoordinator)")
        
        // Validate that the context has a persistent store coordinator
        guard managedObjectContext.persistentStoreCoordinator != nil else {
            print("❌ Managed object context is not connected to a persistent store coordinator")
            return
        }
        
        managedObjectContext.perform {
            let forumsWithThemes = Theme.forumsWithSpecificThemes
            let request = Forum.makeFetchRequest()
            request.returnsObjectsAsFaults = false
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(Forum.forumID), forumsWithThemes)
            request.sortDescriptors = [
                NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true),
                NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)
            ]
            
            do {
                let fetchedForums = try managedObjectContext.fetch(request)
                DispatchQueue.main.async {
                    self.forums = fetchedForums
                }
            } catch {
                print("❌ Failed to fetch forums: \(error)")
            }
        }
    }
}

private struct ForumThemeSection: View {
    let forum: Forum
    @Environment(\.theme) private var theme
    
    var body: some View {
        Section(header: Text(forum.name ?? "Unknown Forum")) {
            ForEach(Theme.Mode.allCases, id: \.self) { mode in
                NavigationLink(destination: destinationView(for: mode)) {
                    HStack {
                        Text(mode.localizedDescription)
                            .foregroundColor(theme[color: "listTextColor"] ?? Color.primary)
                        
                        Spacer()
                        
                        Text(currentThemeName(for: mode))
                            .foregroundColor(theme[color: "listSecondaryTextColor"] ?? Color.secondary)
                            .font(.caption)
                    }
                }
                .listRowBackground(theme[color: "listBackgroundColor"] ?? Color(UIColor.systemBackground))
            }
        }
    }
    
    private func destinationView(for mode: Theme.Mode) -> some View {
        SwiftUIThemePickerView(mode: mode, forumID: forum.forumID)
            .navigationTitle("\(forum.name ?? "") \(mode.localizedDescription)")
            .navigationBarTitleDisplayMode(.large)
    }
    
    private func currentThemeName(for mode: Theme.Mode) -> String {
        let currentTheme = Theme.currentTheme(for: ForumID(forum.forumID), mode: mode)
        return currentTheme.descriptiveName
    }
}

extension Theme.Mode {
    var localizedDescription: String {
        switch self {
        case .light:
            return String(localized: "Light", bundle: .module)
        case .dark:
            return String(localized: "Dark", bundle: .module)
        }
    }
}

#Preview {
    NavigationView {
        SwiftUIForumSpecificThemesView()
            .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
    }
}