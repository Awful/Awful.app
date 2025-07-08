//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import CoreData
import os
import SwiftUI

private let Log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SettingsViewController")

final class SettingsViewController: HostingController<SettingsContainerView> {
    let managedObjectContext: NSManagedObjectContext
    private var containerView: SettingsContainerView

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext

        let currentUser: User? = managedObjectContext.performAndWait {
            guard let userID = UserDefaults.standard.value(for: Settings.userID) else {
                return nil
            }
            return User.objectForKey(objectKey: UserKey(
                userID: userID,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }

        // Allows indirect passing of `self` into root view actions before super.init().
        class UnownedBox {
            unowned var contents: SettingsViewController!
        }
        let box = UnownedBox()

        containerView = SettingsContainerView(
            appIconDataSource: makeAppIconDataSource(),
            currentUser: currentUser,
            emptyCache: { box.contents.emptyCache() },
            goToAwfulThread: { box.contents.goToAwfulThread() },
            // Not sure how to tell for real, seems like a decent proxy?
            hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
            isMac: ProcessInfo.processInfo.isMacCatalystApp,
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            logOut: { AppDelegate.instance.logOut() },
            managedObjectContext: managedObjectContext
        )
        
        super.init(rootView: containerView)
        box.contents = self

        title = String(localized: "Settings", bundle: .module)
        
        // Listen for login state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .DidLogIn,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .DidLogOut,
            object: nil
        )
    }
    
    @objc private func loginStateChanged() {
        // Refresh the user data when login state changes
        let currentUser: User? = managedObjectContext.performAndWait {
            guard let userID = UserDefaults.standard.value(for: Settings.userID) else {
                return nil
            }
            return User.objectForKey(objectKey: UserKey(
                userID: userID,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }
        
        // Update the container view with the new user
        containerView = SettingsContainerView(
            appIconDataSource: makeAppIconDataSource(),
            currentUser: currentUser,
            emptyCache: { [weak self] in self?.emptyCache() },
            goToAwfulThread: { [weak self] in self?.goToAwfulThread() },
            hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
            isMac: ProcessInfo.processInfo.isMacCatalystApp,
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            logOut: { AppDelegate.instance.logOut() },
            managedObjectContext: managedObjectContext
        )
        
        rootView = containerView
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

/// See the `README.md` section "Alternate App Icons" for more info.
private let appIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: String(localized: "Bars", bundle: .module), imageName: "Bars v2"),
    .init(accessibilityLabel: String(localized: "Pride", bundle: .module), imageName: "Pride v2"),
    .init(accessibilityLabel: String(localized: "Trans", bundle: .module), imageName: "Trans v2"),
    .init(accessibilityLabel: String(localized: "V", bundle: .module), imageName: "V v2"),
    .init(accessibilityLabel: String(localized: "Ghost", bundle: .module), imageName: "Ghost v2"),
    .init(accessibilityLabel: String(localized: "Froggo", bundle: .module), imageName: "Frog v2"),
    .init(accessibilityLabel: String(localized: "Froggo (purple)", bundle: .module), imageName: "Frog Purple v2"),
    .init(accessibilityLabel: String(localized: "Doggo", bundle: .module), imageName: "Doggo"),
    .init(accessibilityLabel: String(localized: "Doggo poking tongue", bundle: .module), imageName: "Doggo Tongue"),
    .init(accessibilityLabel: String(localized: "Five", bundle: .module), imageName: "5"),
    .init(accessibilityLabel: String(localized: "Creep", bundle: .module), imageName: "Creep"),
    .init(accessibilityLabel: String(localized: "Riker", bundle: .module), imageName: "Riker"),
    .init(accessibilityLabel: String(localized: "Smith", bundle: .module), imageName: "Smith"),
]

@MainActor private func makeAppIconDataSource() -> AppIconDataSource {
    let selectedIconName = UIApplication.shared.alternateIconName
    let selected = appIcons.first { $0.imageName == selectedIconName } ?? appIcons.first!
    return AppIconDataSource(
        appIcons: appIcons,
        imageLoader: { _ in Image(systemName: "app.fill") },
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
    var currentUser: User?
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isMac: Bool
    let isPad: Bool
    let logOut: () -> Void
    let managedObjectContext: NSManagedObjectContext

    var body: some View {
        Group {
            if let currentUser {
                LoggedInSettings(
                    appIconDataSource: appIconDataSource,
                    currentUser: currentUser,
                    emptyCache: emptyCache,
                    goToAwfulThread: goToAwfulThread,
                    hasRegularSizeClassInLandscape: hasRegularSizeClassInLandscape,
                    isMac: isMac,
                    isPad: isPad,
                    logOut: logOut)
            } else {
                Text("Not Logged In")
            }
        }
        .environment(\.managedObjectContext, managedObjectContext)
        .themed()
    }
}

private struct LoggedInSettings: View {
    let appIconDataSource: AppIconDataSource
    @ObservedObject var currentUser: User
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isMac: Bool
    let isPad: Bool
    let logOut: () -> Void

    var body: some View {
        SettingsView(
            appIconDataSource: appIconDataSource,
            avatarURL: currentUser.avatarURL,
            canOpenURL: UIApplication.shared.canOpenURL(_:),
            currentUsername: currentUser.username ?? "",
            emptyCache: emptyCache,
            goToAwfulThread: goToAwfulThread,
            hasRegularSizeClassInLandscape: hasRegularSizeClassInLandscape,
            isMac: isMac,
            isPad: isPad,
            logOut: logOut
        )
    }
}
