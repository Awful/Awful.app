//  SetBookmarkColor.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import SwiftUI

private let Log = Logger.get()

private extension StarCategory {
    var themeKey: String {
        switch self {
        case .orange: return "unreadBadgeOrangeColor"
        case .red: return "unreadBadgeRedColor"
        case .yellow: return "unreadBadgeYellowColor"
        case .cyan: return "unreadBadgeCyanColor"
        case .green: return "unreadBadgeGreenColor"
        case .purple: return "unreadBadgePurpleColor"
        case .none: return "unreadBadgeBlueColor"
        }
    }
}

private struct BookmarkColor: View {
    @Binding var selection: StarCategory
    let starCategory: StarCategory
    @SwiftUI.Environment(\.theme) var theme

    var body: some View {
        let color = theme[color: starCategory.themeKey]!
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .padding(10)

            if selection == starCategory {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
            }
        }
    }
}

struct BookmarkColorPicker: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    let setBookmarkColor: (AwfulThread, StarCategory) async throws -> Void
    let starCategories = Array(StarCategory.allCases.filter { $0 != .none })
    @SwiftUI.Environment(\.theme) var theme
    @ObservedObject var thread: AwfulThread

    private func didTap(_ starCategory: StarCategory) {
        Task {
            do {
                try await setBookmarkColor(thread, starCategory)
                dismiss()
            } catch {
                Log.e("Could not set thread \(thread.threadID) category to \(starCategory.rawValue)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            theme[color: "sheetBackgroundColor"]!
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text(thread.title ?? "")
                    .foregroundColor(theme[color: "sheetTitleColor"]!)
                    .font(.system(size: 16.0, weight: .regular, design: .rounded))
                    .padding()

                HStack {
                    ForEach(starCategories, id: \.rawValue) { starCategory in
                        Button(action: { didTap(starCategory) }) {
                            BookmarkColor(
                                selection: $thread.starCategory,
                                starCategory: starCategory
                            )
                        }
                    }
                }

                Spacer()
            }
        }
    }
}

struct BookmarkColorPicker_Previews: PreviewProvider {

    static func makeContext() -> NSManagedObjectContext {
        let psc = NSPersistentStoreCoordinator(managedObjectModel: DataStore.model)
        try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: URL(fileURLWithPath: "/dev/null"))
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = psc
        return context
    }

    static func makeThread(in context: NSManagedObjectContext) -> AwfulThread {
        let thread = AwfulThread.insert(into: context)
        thread.setValue(Date(), forKey: "lastModifiedDate")
        thread.threadID = "fake"
        thread.title = "An exquisitely bookmarked thread"
        try! context.save()
        return thread
    }

    static var previews: some View {
        UserDefaults.standard.register(defaults: [Settings.defaultLightThemeName.key: "default"])

        let context = makeContext()
        return BookmarkColorPicker(setBookmarkColor: { _, _ in }, thread: makeThread(in: context))
            .environment(\.managedObjectContext, context) // keep context around
    }
}
