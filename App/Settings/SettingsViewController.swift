//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import Combine
import CoreData
import SwiftUI

final class SettingsViewController: HostingController<SettingsContainerView> {
    let managedObjectContext: NSManagedObjectContext
    private var cacheSizeText: CurrentValueSubject<String, Never>!

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
        let cacheSizeText = CurrentValueSubject<String, Never>("Calculating…")

        super.init(rootView: SettingsContainerView(
            appIconDataSource: makeAppIconDataSource(),
            authenticateImgurAccount: { box.contents.authenticateImgurAccount() },
            cacheSizeText: cacheSizeText,
            currentUser: currentUser,
            emptyCache: { box.contents.emptyCache() },
            goToAwfulThread: { box.contents.goToAwfulThread() },
            // Not sure how to tell for real, seems like a decent proxy?
            hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
            isMac: ProcessInfo.processInfo.isMacCatalystApp,
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            logOut: { AppDelegate.instance.logOut() },
            managedObjectContext: managedObjectContext,
            onScrollOffsetFromTop: { box.contents.updateNavigationBarForScrollOffset($0) },
            resetSettings: { box.contents.resetSettings() }
        ))
        self.cacheSizeText = cacheSizeText
        box.contents = self

        title = String(localized: "Settings", bundle: .module)
        tabBarItem.image = UIImage(named: "cog")
        tabBarItem.selectedImage = UIImage(named: "cog-filled")

        themeDidChange()

        NotificationCenter.default.addObserver(self, selector: #selector(dataStoreDidReset), name: .dataStoreDidReset, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func dataStoreDidReset() {
        // The current User object is tied to the old store. Re-fetch (findOrCreate) so the
        // Settings header doesn't crash when it tries to fault the invalidated object.
        let newUser = managedObjectContext.performAndWait {
            User.objectForKey(objectKey: UserKey(
                userID: UserDefaults.standard.value(for: Settings.userID)!,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }
        rootView = SettingsContainerView(
            appIconDataSource: rootView.appIconDataSource,
            authenticateImgurAccount: rootView.authenticateImgurAccount,
            cacheSizeText: rootView.cacheSizeText,
            currentUser: newUser,
            emptyCache: rootView.emptyCache,
            goToAwfulThread: rootView.goToAwfulThread,
            hasRegularSizeClassInLandscape: rootView.hasRegularSizeClassInLandscape,
            isMac: rootView.isMac,
            isPad: rootView.isPad,
            logOut: rootView.logOut,
            managedObjectContext: rootView.managedObjectContext,
            onScrollOffsetFromTop: rootView.onScrollOffsetFromTop,
            resetSettings: rootView.resetSettings
        )
    }

    /// Drives the iOS 26 liquid-glass nav bar transition (opaque at top, transparent once
    /// scrolled) from the SwiftUI Form's scroll position, which otherwise never reaches the
    /// navigation controller.
    private func updateNavigationBarForScrollOffset(_ offsetFromTop: CGFloat) {
        guard #available(iOS 26.0, *),
              LiquidGlass.isEnabled,
              let navController = navigationController as? NavigationController
        else { return }
        let transitionDistance: CGFloat = 30.0
        let progress = max(0, min(1, offsetFromTop / transitionDistance))
        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: Float(progress)))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshCacheSize()
        refreshAccountFeaturesOnAppear()
    }

    /// Fetch the latest account features whenever Settings is shown so the displayed upgrade
    /// status reflects reality immediately rather than waiting for the background timer. Errors
    /// are ignored — the last-known stored values remain, and the timer will retry.
    private func refreshAccountFeaturesOnAppear() {
        guard ForumsClient.shared.isLoggedIn else { return }
        Task { try? await refreshAccountFeatures() }
    }

    private func refreshCacheSize() {
        Task {
            let size = await AppDelegate.instance.calculateCacheSize()
            cacheSizeText.send(Self.formatByteCount(size))
        }
    }

    func emptyCache() {
        Task {
            let sizeBefore = await AppDelegate.instance.calculateCacheSize()
            await AppDelegate.instance.emptyCacheAndResetStore()
            let sizeAfter = await AppDelegate.instance.calculateCacheSize()

            let delta = max(sizeBefore - sizeAfter, 0)
            let message = "You cleared \(Self.formatByteCount(delta))! Some system-managed files can't be removed, so a small amount of cache usage is normal."
            let alertController = UIAlertController(title: "Cache Cleared", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })
            self.present(alertController, animated: true)

            refreshCacheSize()
        }
    }

    private static func formatByteCount(_ bytes: Int64) -> String {
        let measurement = Measurement(value: Double(bytes), unit: UnitInformationStorage.bytes)
        if bytes < 1_000_000 {
            return measurement.converted(to: .kilobytes).formatted(
                .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))
            )
        } else {
            return measurement.converted(to: .megabytes).formatted(
                .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1)))
            )
        }
    }

    func resetSettings() {
        let alert = UIAlertController(
            title: "Reset All Settings?",
            message: "This will restore all preferences to their defaults. You will remain logged in.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            UserDefaults.standard.resetPreferences()
        })
        present(alert, animated: true)
    }

    /// Offers the Imgur OAuth login as soon as the user switches uploads to "Imgur Account", so
    /// they don't first hit the login prompt mid-composition. Cancelling leaves the setting alone;
    /// the composer prompts again at image upload time.
    func authenticateImgurAccount() {
        guard ImgurAuthManager.shared.needsAuthentication || ImgurAuthManager.shared.checkTokenExpiry() else { return }
        ImgurAuthManager.shared.authenticate(from: self) { success in
            DispatchQueue.main.async {
                let alert: UIAlertController
                if success {
                    alert = UIAlertController(
                        title: "Logged In to Imgur",
                        message: "Images you post will now upload to your Imgur account.",
                        alertActions: [.ok()]
                    )
                } else {
                    alert = UIAlertController(
                        title: "Imgur Login Incomplete",
                        message: "You can keep using this setting. You'll be asked to log in when you upload an image.",
                        alertActions: [.ok()]
                    )
                }
                self.present(alert, animated: true)
            }
        }
    }

    func goToAwfulThread() {
        AppDelegate.instance.open(route: .threadPage(threadID: Environment.feedbackThreadID, page: .nextUnread, .seen))
    }

    override func themeDidChange() {
        super.themeDidChange()

        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = title
        }
    }
}

/// See the `README.md` section "Alternate App Icons" for more info. Now ordered in a 3 x 5 grid
private let appIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: String(localized: "Rated five", bundle: .module), imageName: AppIconImageNames.rated_five),
    .init(accessibilityLabel: String(localized: "Rated five (trans flag)", bundle: .module), imageName: AppIconImageNames.rated_five_trans),
    .init(accessibilityLabel: String(localized: "Rated five (pride flag)", bundle: .module), imageName: AppIconImageNames.rated_five_pride),
    
    .init(accessibilityLabel: String(localized: "Froggo", bundle: .module), imageName: AppIconImageNames.froggo),
    .init(accessibilityLabel: String(localized: "Doggo", bundle: .module), imageName: AppIconImageNames.staredog),
    .init(accessibilityLabel: String(localized: "V", bundle: .module), imageName: AppIconImageNames.v),
    
    .init(accessibilityLabel: String(localized: "Froggo (purple)", bundle: .module), imageName: AppIconImageNames.froggo_purple),
    .init(accessibilityLabel: String(localized: "Doggo poking tongue", bundle: .module), imageName: AppIconImageNames.staredog_tongue),
    .init(accessibilityLabel: String(localized: "Ghost", bundle: .module), imageName: AppIconImageNames.ghost_blue),
    
    .init(accessibilityLabel: String(localized: "Cute", bundle: .module), imageName: AppIconImageNames.cute),
    .init(accessibilityLabel: String(localized: "Stare", bundle: .module), imageName: AppIconImageNames.stare),
    .init(accessibilityLabel: String(localized: "Five", bundle: .module), imageName: AppIconImageNames.five),
    
    .init(accessibilityLabel: String(localized: "Smith", bundle: .module), imageName: AppIconImageNames.smith),
    .init(accessibilityLabel: String(localized: "Creep", bundle: .module), imageName: AppIconImageNames.greenface),
    .init(accessibilityLabel: String(localized: "Riker", bundle: .module), imageName: AppIconImageNames.riker),
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
    let authenticateImgurAccount: () -> Void
    let cacheSizeText: CurrentValueSubject<String, Never>
    @ObservedObject var currentUser: User
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isMac: Bool
    let isPad: Bool
    let logOut: () -> Void
    let managedObjectContext: NSManagedObjectContext
    let onScrollOffsetFromTop: (CGFloat) -> Void
    let resetSettings: () -> Void

    @State private var displayedCacheSize: String = "Calculating…"

    var body: some View {
        if #available(iOS 26.0, *) {
            // Report the Form's scroll position so the hosting controller can drive the
            // liquid-glass nav bar transition. The transformed value only changes with
            // vertical scrolling, so inner horizontal scrollers (the app icon grid) don't fire it.
            core.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offsetFromTop in
                onScrollOffsetFromTop(offsetFromTop)
            }
        } else {
            core
        }
    }

    private var core: some View {
        SettingsView(
            appIconDataSource: appIconDataSource,
            authenticateImgurAccount: authenticateImgurAccount,
            avatarURL: currentUser.avatarURL,
            cacheSizeText: displayedCacheSize,
            canOpenURL: UIApplication.shared.canOpenURL(_:),
            currentUsername: currentUser.username ?? "",
            emptyCache: emptyCache,
            goToAwfulThread: goToAwfulThread,
            hasRegularSizeClassInLandscape: hasRegularSizeClassInLandscape,
            isMac: isMac,
            isPad: isPad,
            logOut: logOut,
            resetSettings: resetSettings
        )
        .environment(\.managedObjectContext, managedObjectContext)
        .themed()
        .onReceive(cacheSizeText) { newValue in
            displayedCacheSize = newValue
        }
    }
}

extension SettingsViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .settings
    }
}
