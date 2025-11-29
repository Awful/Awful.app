//  AppDelegate.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AVFoundation
import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import Nuke
import os
import Smilies
import UIKit
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

final class AppDelegate: UIResponder, UIApplicationDelegate {
    private(set) static var instance: AppDelegate!

    private var announcementListRefresher: AnnouncementListRefresher?
    @FoilDefaultStorage(Settings.autoDarkTheme) private var automaticDarkTheme
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    private var dataStore: DataStore!
    @FoilDefaultStorage(Settings.defaultDarkThemeName) private var defaultDarkTheme
    @FoilDefaultStorage(Settings.defaultLightThemeName) private var defaultLightTheme
    private var inboxRefresher: PrivateMessageInboxRefresher?
    var managedObjectContext: NSManagedObjectContext { return dataStore.mainManagedObjectContext }
    private var openCopiedURLController: OpenCopiedURLController?
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.enableCustomTitlePostLayout) private var showCustomTitles
    var window: UIWindow?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.instance = self

        UserDefaults.standard.register(defaults: Theme.forumSpecificDefaults)
        SettingsMigration.migrate(.standard)

        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let storeURL = appSupport.appendingPathComponent("CachedForumData", isDirectory: true)
        dataStore = DataStore(storeDirectoryURL: storeURL)
        
        DispatchQueue.global(qos: .background).async(execute: removeOldDataStores)
        
        ForumsClient.shared.managedObjectContext = managedObjectContext
        ForumsClient.shared.baseURL = URL(string: "https://forums.somethingawful.com/")!
        ForumsClient.shared.didRemotelyLogOut = { [weak self] in
            self?.logOut()
        }

        URLCache.shared = {
            #if targetEnvironment(macCatalyst)
            return URLCache(memoryCapacity: megabytes(5), diskCapacity: megabytes(50), directory: nil)
            #else
            return URLCache(memoryCapacity: megabytes(5), diskCapacity: megabytes(50), diskPath: nil)
            #endif
        }()

        return true
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ignoreSilentSwitchWhenPlayingEmbeddedVideo()
        
        showPromptIfLoginCookieExpiresSoon()

        announcementListRefresher = AnnouncementListRefresher(client: ForumsClient.shared, minder: RefreshMinder.sharedMinder)
        inboxRefresher = PrivateMessageInboxRefresher(client: ForumsClient.shared, minder: RefreshMinder.sharedMinder)
        PostsViewExternalStylesheetLoader.shared.refreshIfNecessary()
        
        do {
            NotificationCenter.default.addObserver(self, selector: #selector(forumSpecificThemeDidChange), name: Theme.themeForForumDidChangeNotification, object: Theme.self)
            NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
        }

        do {
            $automaticDarkTheme
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.automaticallyUpdateDarkModeEnabledIfNecessary() }
                .store(in: &cancellables)

            $darkMode
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.showSnapshotDuringThemeDidChange() }
                .store(in: &cancellables)

            // if darkMode changes,
            // or if defaultDarkTheme changes while in dark mode,
            // or if defaultLightTheme changes while in light mode:
            // snapshot!
            
            let darkDefaultChange = $defaultDarkTheme
                .dropFirst()
                .filter { [weak self] _ in self?.darkMode == true }
            let lightDefaultChange = $defaultLightTheme
                .dropFirst()
                .filter { [weak self] _ in self?.darkMode == false }
            Publishers.Merge(darkDefaultChange, lightDefaultChange)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.showSnapshotDuringThemeDidChange() }
                .store(in: &cancellables)

            $showCustomTitles
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.setShowAvatarsSetting() }
                .store(in: &cancellables)
        }

        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(false)
        
        updateShortcutItems()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(true)

        // Screen brightness may have changed while the app wasn't paying attention.
        automaticallyUpdateDarkModeEnabledIfNecessary()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        do {
            try managedObjectContext.save()
        } catch {
            logger.error("Failed to save context on background: \(error)")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        do {
            try managedObjectContext.save()
        } catch {
            logger.error("Failed to save context on termination: \(error)")
        }
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return ForumsClient.shared.isLoggedIn
    }
    
    func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
        coder.encode(currentInterfaceVersion.rawValue, forKey: interfaceVersionKey)
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        guard ForumsClient.shared.isLoggedIn else { return false }
        return coder.decodeInteger(forKey: interfaceVersionKey) == currentInterfaceVersion.rawValue
    }

    func application(_ application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        return rootViewControllerStack.viewControllerWithRestorationIdentifierPath(identifierComponents)
    }
    
    func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
        try! managedObjectContext.save()
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        guard
            ForumsClient.shared.isLoggedIn,
            let route = try? AwfulRoute(url)
            else { return false }

        open(route: route)
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let router = urlRouter, let route = userActivity.route else { return false }
        return router.route(route)
    }
    
    func logOut() {
        // Logging out doubles as an "empty cache" button.
        let cookieJar = HTTPCookieStorage.shared
        for cookie in cookieJar.cookies ?? [] {
            cookieJar.deleteCookie(cookie)
        }
        UserDefaults.standard.removeAllObjectsInMainBundleDomain()
        emptyCache()
        
        let loginVC = LoginViewController.newFromStoryboard()
        loginVC.completionBlock = { [weak self] (login) in
            guard let self = self else { return }
            self.setRootViewController(self.rootViewControllerStack.rootViewController, animated: true, completion: { [weak self] in
                guard let self = self else { return }
                self.rootViewControllerStack.didAppear()
                self.loginViewController = nil
            })
        }
        
        setRootViewController(loginVC.enclosingNavigationController, animated: true) { [weak self] in
            self?._rootViewControllerStack = nil
            self?.urlRouter = nil
            
            self?.dataStore.deleteStoreAndReset()
        }
    }
    
    func emptyCache() {
        URLCache.shared.removeAllCachedResponses()
        ImageCache.shared.removeAll()
    }

    func open(route: AwfulRoute) {
        urlRouter?.route(route)
    }
    
    func automaticallyUpdateDarkModeEnabledIfNecessary() {
        guard automaticDarkTheme else { return }

        let shouldDarkModeBeEnabled = (window ?? keyWindow)?.traitCollection.userInterfaceStyle == .dark
        if shouldDarkModeBeEnabled != darkMode {
            darkMode.toggle()
        }
    }

    func updateShortcutItems() {
        guard urlRouter != nil else {
            UIApplication.shared.shortcutItems = []
            return
        }
        
        var shortcutItems: [UIApplicationShortcutItem] = []
        
        // Add a shortcut to quick-open to bookmarks.
        // For whatever reason, the first shortcut item is the one closest to the bottom.
        let bookmarksImage = UIApplicationShortcutIcon(templateImageName: "bookmarks")
        shortcutItems.append(UIApplicationShortcutItem(type: "awful://bookmarks", localizedTitle: "Bookmarks", localizedSubtitle: nil, icon: bookmarksImage, userInfo: nil))
        
        // Add a shortcut for favorited forums, in the order they appear in the list.
        let fetchRequest = ForumMetadata.makeFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "favorite = YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "favoriteIndex", ascending: true)]
        fetchRequest.fetchLimit = 3
        let favourites: [ForumMetadata]
        do {
            favourites = try managedObjectContext.fetch(fetchRequest)
        } catch {
            logger.warning("favorites fetch failed: \(error)")
            return
        }
        let favouritesIcon = UIApplicationShortcutIcon(templateImageName: "star-off")
        for metadata in favourites.lazy.reversed() {
            let urlString = "awful://forums/\(metadata.forum.forumID)"
            // I wish we could get the forum's alt-text sanely somehow :(
            shortcutItems.append(UIApplicationShortcutItem(type: urlString, localizedTitle: metadata.forum.name ?? "", localizedSubtitle: nil, icon: favouritesIcon, userInfo: nil))
        }
        
        UIApplication.shared.shortcutItems = shortcutItems
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard
            let url = URL(string: shortcutItem.type),
            let route = try? AwfulRoute(url)
            else { return completionHandler(false) }

        open(route: route)
        completionHandler(true)
    }
    
    private var _rootViewControllerStack: RootViewControllerStack?
    private var urlRouter: AwfulURLRouter?
    var rootViewControllerStack: RootViewControllerStack {
        if let stack = _rootViewControllerStack { return stack }
        let stack = RootViewControllerStack(managedObjectContext: managedObjectContext)
        urlRouter = AwfulURLRouter(rootViewController: stack.rootViewController, managedObjectContext: managedObjectContext)
        stack.userInterfaceStyleDidChange = { [weak self] in self?.automaticallyUpdateDarkModeEnabledIfNecessary() }
        _rootViewControllerStack = stack
        return stack
    }

    lazy var loginViewController: LoginViewController! = {
        let loginVC = LoginViewController.newFromStoryboard()
        loginVC.completionBlock = { [weak self] (login) in
            guard let self = self else { return }
            self.swapToMainViewController()
        }
        return loginVC
    }()

    func swapToMainViewController() {
        guard let window = self.window ?? self.keyWindow else { return }

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = self.rootViewControllerStack.rootViewController
        }) { [weak self] _ in
            self?.rootViewControllerStack.didAppear()
            self?.loginViewController = nil
        }
    }

    func setupOpenCopiedURLController() {
        guard openCopiedURLController == nil else { return }
        guard let window = self.window ?? self.keyWindow else { return }

        openCopiedURLController = OpenCopiedURLController(window: window, router: { [unowned self] in
            self.open(route: $0)
        })
    }

    private var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private extension AppDelegate {
    func setRootViewController(_ rootViewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let window = window ?? keyWindow else { return }
        UIView.transition(with: window, duration: animated ? 0.3 : 0, options: .transitionCrossDissolve, animations: {
            window.rootViewController = rootViewController
            }) { (completed) in
                completion?()
        }
    }

    func themeDidChange() {
        guard let window = window ?? keyWindow else { return }

        window.tintColor = Theme.defaultTheme()["tintColor"]

        if let root = window.rootViewController {
            for vc in root.subtree {
                if vc.isViewLoaded, let themeable = vc as? Themeable {
                    themeable.themeDidChange()
                }
            }
        }
    }
    
    @objc private func forumSpecificThemeDidChange(_ notification: Notification) {
        showSnapshotDuringThemeDidChange()
    }
    
    private func showSnapshotDuringThemeDidChange() {
        guard let window = window ?? keyWindow else {
            themeDidChange()
            return
        }
        if let snapshot = window.snapshotView(afterScreenUpdates: false) {
            window.addSubview(snapshot)
            themeDidChange()
            
            UIView.transition(from: snapshot, to: window, duration: 0.2, options: [.transitionCrossDissolve, .showHideTransitionViews], completion: { completed in
                snapshot.removeFromSuperview()
            })
        } else {
            themeDidChange()
        }
    }
    
    private func setShowAvatarsSetting() {
        if showCustomTitles {
            showAvatars = true
        }
    }

    @objc func preferredContentSizeDidChange(_ notification: Notification) {
        themeDidChange()
    }

    func showPromptIfLoginCookieExpiresSoon() {
        guard
            let expiryDate = ForumsClient.shared.loginCookieExpiryDate,
            expiryDate.timeIntervalSinceNow < loginCookieExpiringSoonThreshold
            else { return }
        let lastPromptDate = UserDefaults.standard.object(forKey: loginCookieLastExpiryPromptDateKey) as? Date ?? .distantFuture
        guard lastPromptDate.timeIntervalSinceNow < -loginCookieExpiryPromptFrequency else { return }

        let alert = UIAlertController(
            title: LocalizedString("session-expiry-imminent.title"),
            message: String(format: LocalizedString("session-expiry-imminent.message"), DateFormatter.localizedString(from: expiryDate, dateStyle: .short, timeStyle: .none)),
            alertActions: [.default(title: LocalizedString("ok"), handler: {
                UserDefaults.standard.set(Date(), forKey: loginCookieLastExpiryPromptDateKey)
            })]
        )
        (window ?? keyWindow)?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

private func removeOldDataStores() {
    // Obsolete data stores should be cleaned up so we're not wasting space.
    let fm = FileManager.default
    var pendingDeletions: [URL] = []
    
    // The Documents directory is pre-Awful 3.0. It was unsuitable because it was not user-managed data.
    // The Caches directory was used through Awful 3.1. It was unsuitable once user data was stored in addition to cached presentation data.
    // Both stores were under the same filename.
    let documents = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let caches = try! fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    for directory in [documents, caches] {
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants, errorHandler: { (url, error) -> Bool in
            logger.info("error enumerating \(url.absoluteString)")
            return true
        }) else { continue }
        for url in enumerator {
            // Check for prefix, not equality, as there could be associated files (SQLite indexes or logs) that should also disappear.
            if
                let url = url as? URL,
                url.lastPathComponent.hasPrefix("AwfulData.sqlite")
            {
                pendingDeletions.append(url)
            }
        }
    }

    // The user's avatar (for showing in Settings) and any thread tags not included in the app bundle used to get downloaded to a couple Caches subdirectories. Now Nuke handles everything, so let's clean up the old caches.
    pendingDeletions += [
        caches.appendingPathComponent("Avatars", isDirectory: true),
        caches.appendingPathComponent("Thread Tags", isDirectory: true)]
    
    for url in pendingDeletions {
        do {
            try fm.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // nop
        } catch {
            logger.info("error deleting file at \(url.absoluteString): \(error)")
        }
    }
}

/// Returns the number of bytes in the passed-in number of megabytes.
private func megabytes(_ mb: Int) -> Int {
    return mb * 1024 * 1024
}

private func days(_ days: Int) -> TimeInterval {
    return TimeInterval(days) * 24 * 60 * 60
}

// Value is an InterfaceVersion integer. Encoded when preserving state, and possibly useful for determining whether to decode state or to somehow migrate the preserved state.
private let interfaceVersionKey = "AwfulInterfaceVersion"

private enum InterfaceVersion: Int {
    /// Interface for Awful 2, the version that runs on iOS 7. On iPhone, a basement-style menu is the root view controller. On iPad, a custom split view controller is the root view controller, and it hosts a vertical tab bar controller as its primary view controller.
    case version2
    
    /// Interface for Awful 3, the version that runs on iOS 8. The primary view controller is a UISplitViewController on both iPhone and iPad.
    case version3
}

private let currentInterfaceVersion: InterfaceVersion = .version3

private func ignoreSilentSwitchWhenPlayingEmbeddedVideo() {
    do {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: .default)
    } catch {
        logger.debug("error setting audio session category: \(error)")
    }
}

private let loginCookieExpiringSoonThreshold = days(7)
private let loginCookieLastExpiryPromptDateKey = "com.awfulapp.Awful.LastCookieExpiringPromptDate"
private let loginCookieExpiryPromptFrequency = days(2)
