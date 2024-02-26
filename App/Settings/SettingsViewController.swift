//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import CoreData
import SwiftUI

private let Log = Logger.get()

final class SettingsViewController: UIHostingController<SettingsContainerView> {
    let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext

        let appIconDataSource = AppIconDataSource(
            iconsLoader: loadAppIcons,
            imageLoader: { UIImage(named: $0.rawValue).flatMap(Image.init(uiImage:)) },
            selectedIconName: UIApplication.shared.alternateIconName.map { AppIconDataSource.AppIconName($0) },
            setCurrentIconName: { try await UIApplication.shared.setAlternateIconName($0?.rawValue) }
        )

        let currentUser = managedObjectContext.performAndWait {
            User.objectForKey(objectKey: UserKey(
                userID: UserDefaults.standard.value(for: Settings.userID)!,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }

        // Allows indirect passing of `self` into root view actions before super.init().
        class UnownedBox {
            unowned var contents: SettingsViewController!
        }
        let box = UnownedBox()

        super.init(rootView: SettingsContainerView(
            appIconDataSource: appIconDataSource,
            currentUser: currentUser,
            emptyCache: { box.contents.emptyCache() },
            goToAwfulThread: { box.contents.goToAwfulThread() },
            // Not sure how to tell for real, seems like a decent proxy?
            hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            logOut: { AppDelegate.instance.logOut() },
            managedObjectContext: managedObjectContext
        ))
        box.contents = self

        title = String(localized: "Settings", bundle: .module)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func emptyCache() {
        let usageBefore = Measurement(value: Double(URLCache.shared.currentDiskUsage), unit: UnitInformationStorage.bytes)
        AppDelegate.instance.emptyCache()
        let usageAfter = Measurement(value: Double(URLCache.shared.currentDiskUsage), unit: UnitInformationStorage.bytes)
        let delta = (usageBefore - usageAfter).converted(to: .megabytes)
        let message = "You cleared up \(delta.formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1)))))! Great job, go hog wild!!"
        let alertController = UIAlertController(title: "Cache Cleared", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { action in
            self.dismiss(animated: true)
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
    }

    func goToAwfulThread() {
        AppDelegate.instance.open(route: .threadPage(threadID: "3837546", page: .nextUnread, .seen))
    }
}

private func loadAppIcons() async -> [AppIconDataSource.AppIconName] {
    guard let icons = Bundle.module.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any] else {
        Log.e("could not find CFBundleIcons in Info.plist")
        return []
    }

    guard let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
          let primaryIconName = primary["CFBundleIconName"] as? String
    else {
        Log.e("could not find CFBundlePrimaryIcon in Info.plist")
        return []
    }

    let alternates = icons["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
    let alternateIconNames = alternates.values
        .compactMap { $0 as? [String: Any] }
        .compactMap { $0["CFBundleIconName"] as? String }
        .sorted()

    return ([primaryIconName] + alternateIconNames).map { AppIconDataSource.AppIconName($0) }
}

/// Wrapper for observing the current `User`.
struct SettingsContainerView: View {
    let appIconDataSource: AppIconDataSource
    @ObservedObject var currentUser: User
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isPad: Bool
    let logOut: () -> Void
    let managedObjectContext: NSManagedObjectContext

    var body: some View {
        SettingsView(
            appIconDataSource: appIconDataSource,
            avatarURL: currentUser.avatarURL,
            canOpenURL: UIApplication.shared.canOpenURL(_:),
            currentUsername: currentUser.username ?? "",
            emptyCache: emptyCache,
            goToAwfulThread: goToAwfulThread,
            hasRegularSizeClassInLandscape: hasRegularSizeClassInLandscape,
            isPad: isPad,
            logOut: logOut
        )
        .environment(\.managedObjectContext, managedObjectContext)
        .themed()
    }
}
