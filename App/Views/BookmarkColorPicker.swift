//  SetBookmarkColor.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import CoreData
import SwiftUI

private let Log = Logger.get()

private struct ThemeKey: EnvironmentKey {
    static var defaultValue: Theme { Theme.defaultTheme() }
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

private extension StarCategory {
    var themeKey: String {
        switch self {
        case .orange: return "unreadBadgeOrangeColor"
        case .red: return "unreadBadgeRedColor"
        case .yellow: return "unreadBadgeYellowColor"
        case .teal: return "unreadBadgeTealColor"
        case .green: return "unreadBadgeGreenColor"
        case .purple: return "unreadBadgePurpleColor"
        case .none: return "unreadBadgeBlueColor"
        }
    }
}
extension Theme {
    subscript(swiftColor colorName: String) -> Color? {
        return self[color: colorName].map { Color($0) }
    }
}

private struct BookmarkColor: View {
    @Binding var selection: StarCategory
    let starCategory: StarCategory
    @SwiftUI.Environment(\.theme) var theme

    var body: some View {
        let color = theme[swiftColor: starCategory.themeKey]!
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
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    let setBookmarkColor: (AwfulThread, StarCategory) async throws -> Void
    @SwiftUI.Environment(\.theme) var theme
    @ObservedObject var thread: AwfulThread

    private func didTap(_ starCategory: StarCategory) {
        let oldSelection = thread.starCategory
        thread.starCategory = starCategory
        try! thread.managedObjectContext?.save()

        Task {
            do {
                try await setBookmarkColor(thread, starCategory)
                presentationMode.wrappedValue.dismiss()
            } catch {
                Log.e("Could not set thread \(thread.threadID) category to \(starCategory.rawValue)")
                thread.starCategory = oldSelection
                try! thread.managedObjectContext?.save()
            }
        }
    }
    
    var body: some View {
        return VStack {
            Text(thread.title ?? "")
                .foregroundColor(theme[swiftColor: "sheetTitleColor"]!)
                .font(.system(size: 16.0, weight: .regular, design: .rounded))
                .padding()

            HStack {
                ForEach(StarCategory.allCases, id: \.rawValue) { starCategory in
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
        .background(theme[swiftColor: "sheetBackgroundColor"]!)
        .edgesIgnoringSafeArea(.all)
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
        UserDefaults.standard.register(defaults: [SettingsKeys.defaultLightTheme: "default"])

        let context = makeContext()
        return BookmarkColorPicker(setBookmarkColor: { _, _ in }, thread: makeThread(in: context))
            .environment(\.managedObjectContext, context) // keep context around
    }
}
