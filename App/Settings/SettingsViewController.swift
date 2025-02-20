//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import CoreData
import SwiftUI

private let Log = Logger.get()

final class SettingsViewController: HostingController<SettingsContainerView> {
    let managedObjectContext: NSManagedObjectContext

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext

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
            appIconDataSource: makeAppIconDataSource(),
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

/// Image names should correspond to the contents of `App Icons.xcassets`. See `README.md` for more info.
private let appIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: String(localized: "Rated five", bundle: .module), imageName: "rated_five_appicon"),
    .init(accessibilityLabel: String(localized: "Rated five (pride flag)", bundle: .module), imageName: "rated_five_pride_appicon"),
    .init(accessibilityLabel: String(localized: "Rated five (trans flag)", bundle: .module), imageName: "rated_five_trans_appicon"),
    .init(accessibilityLabel: String(localized: "V", bundle: .module), imageName: "v_appicon"),
    .init(accessibilityLabel: String(localized: "Ghost", bundle: .module), imageName: "ghost_blue_appicon"),
    .init(accessibilityLabel: String(localized: "Froggo", bundle: .module), imageName: "froggo_appicon"),
    .init(accessibilityLabel: String(localized: "Doggo", bundle: .module), imageName: "staredog_appicon"),
    .init(accessibilityLabel: String(localized: "Five", bundle: .module), imageName: "five_appicon"),
    .init(accessibilityLabel: String(localized: "Creep", bundle: .module), imageName: "greenface_appicon"),
    .init(accessibilityLabel: String(localized: "Riker", bundle: .module), imageName: "riker_appicon"),
    .init(accessibilityLabel: String(localized: "Smith", bundle: .module), imageName: "smith_appicon"),
]

@MainActor private func makeAppIconDataSource() -> AppIconDataSource {
    let selectedIconName = UIApplication.shared.alternateIconName
    let selected = appIcons.first { $0.imageName == selectedIconName } ?? appIcons.first!
    return AppIconDataSource(
        appIcons: appIcons,
        imageLoader: { Image("\($0.imageName)_preview", bundle: .main) },
        selected: selected,
        setter: {
            let iconName = $0 == appIcons.first ? nil : $0.imageName
            try await UIApplication.shared.setAlternateIconName(iconName)
        }
    )
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
