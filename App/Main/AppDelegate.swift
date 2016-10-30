//  AppDelegate.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import AVFoundation
import AwfulCore
import Crashlytics
import Fabric
import GRMustache
import Smilies
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    fileprivate(set) static var instance: AppDelegate!
    fileprivate var dataStore: DataStore!
    var managedObjectContext: NSManagedObjectContext { return dataStore.mainManagedObjectContext }
    var window: UIWindow?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.instance = self
        
        if
            let fabric = Bundle.main.object(forInfoDictionaryKey: "Fabric") as? [String: Any],
            let key = fabric["APIKey"] as? String,
            !key.isEmpty
        {
            Fabric.with([Crashlytics.self])
        }
        
        GRMustache.preventNSUndefinedKeyExceptionAttack()
        
        AwfulSettings.shared().registerDefaults()
        AwfulSettings.shared().migrateOldSettings()
        
        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let storeURL = appSupport.appendingPathComponent("CachedForumData", isDirectory: true)
        let modelURL = Bundle(for: DataStore.self).url(forResource: "Awful", withExtension: "momd")!
        dataStore = DataStore(storeDirectoryURL: storeURL, modelURL: modelURL)
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: removeOldDataStores)
        
        AwfulForumsClient.shared().managedObjectContext = managedObjectContext
        updateClientBaseURL()
        AwfulForumsClient.shared().didRemotelyLogOutBlock = { [weak self] in
            self?.logOut()
        }
        
        AFNetworkActivityIndicatorManager.shared().isEnabled = true
        
        URLCache.shared = URLCache(memoryCapacity: megabytes(5), diskCapacity: megabytes(50), diskPath: nil)
        
        let protocols: [AnyClass] = [ImageURLProtocol.self, MinusFixURLProtocol.self, ResourceURLProtocol.self, WaffleimagesURLProtocol.self]
        for proto in protocols {
            URLProtocol.registerClass(proto)
        }
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.tintColor = Theme.currentTheme["tintColor"]
        
        if AwfulForumsClient.shared().loggedIn {
            setRootViewController(rootViewControllerStack.rootViewController, animated: false, completion: nil)
        } else {
            setRootViewController(loginViewController.enclosingNavigationController, animated: false, completion: nil)
        }
        
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Don't want to lazily create it now.
        _rootViewControllerStack?.didAppear()
        
        ignoreSilentSwitchWhenPlayingEmbeddedVideo()
        
        showPromptIfLoginCookieExpiresSoon()
        
        NewMessageChecker.sharedChecker.refreshIfNecessary()
        PostsViewExternalStylesheetLoader.sharedLoader.refreshIfNecessary()
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeDidChange), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(brightnessDidChange), name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
        
        // Brightness may have changed since app was shut down
        NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: UIScreen.main)

        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(false)
        
        updateShortcutItems()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(true)
        
        guard AwfulForumsClient.shared().loggedIn else { return }
        guard let
            url = UIPasteboard.general.awful_URL,
            let awfulURL = url.awfulURL
            else { return }
        for urlTypes in Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: AnyObject]] ?? [] {
            for urlScheme in urlTypes["CFBundleURLSchemes"] as? [String] ?? [] {
                if urlScheme.caseInsensitiveCompare(url.scheme!) == .orderedSame {
                    return
                }
            }
        }
        
        guard AwfulSettings.shared().lastOfferedPasteboardURL != url.absoluteString else { return }
        AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.message = "Would you like to open this URL in Awful?\n\n\(url.absoluteString)"
        alert.addCancelActionWithHandler(nil)
        alert.addActionWithTitle("Open", handler: { (action) in
            let _ = self.openAwfulURL(awfulURL)
        })
        window?.rootViewController?.present(alert, animated: true, completion: nil)
        
        // Brightness may have changed while app was inactive
        NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: UIScreen.main)

    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return AwfulForumsClient.shared().loggedIn
    }
    
    func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
        coder.encode(currentInterfaceVersion.rawValue, forKey: interfaceVersionKey)
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        guard AwfulForumsClient.shared().loggedIn else { return false }
        return coder.decodeInteger(forKey: interfaceVersionKey) == currentInterfaceVersion.rawValue
    }
    
    func application(_ application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        guard let identifierComponents = identifierComponents as? [String] else { return nil }
        return rootViewControllerStack.viewControllerWithRestorationIdentifierPath(identifierComponents)
    }
    
    func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
        try! managedObjectContext.save()
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        guard AwfulForumsClient.shared().loggedIn else { return false }
        if let scheme = url.scheme, ["awfulhttp", "awfulhttps"].contains(scheme.lowercased()) {
            guard let awfulURL = url.awfulURL else { return false }
            return openAwfulURL(awfulURL)
        }
        return openAwfulURL(url)
    }
    
    func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity) {
        // Bit of future-proofing.
        userActivity.addUserInfoEntries(from: [Handoff.InfoVersionKey: handoffVersion])
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        guard let
            awfulURL = userActivity.awfulURL,
            let router = urlRouter
            else { return false }
        let _ = router.route(awfulURL)
        return true
    }
    
    func logOut() {
        // Logging out doubles as an "empty cache" button.
        let cookieJar = HTTPCookieStorage.shared
        for cookie in cookieJar.cookies ?? [] {
            cookieJar.deleteCookie(cookie)
        }
        URLCache.shared.removeAllCachedResponses()
        
        AwfulSettings.shared().reset()
        AvatarLoader.sharedLoader.emptyCache()
        
        // Do this after resetting settings so that it gets the default baseURL.
        updateClientBaseURL()
        
        setRootViewController(loginViewController.enclosingNavigationController, animated: true) { [weak self] in
            self?._rootViewControllerStack = nil
            self?.urlRouter = nil
            
            self?.dataStore.deleteStoreAndReset()
        }
    }
    
    /**
        Handles an awful:// URL.
     
        - returns: `true` if the awful:// URL made sense, or `false` otherwise.
     */
    @discardableResult func openAwfulURL(_ url: URL) -> Bool {
        guard let router = urlRouter else { return false }
        return router.route(url)
    }
    
    fileprivate func updateShortcutItems() {
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
        let fetchRequest = NSFetchRequest<ForumMetadata>(entityName: ForumMetadata.entityName())
        fetchRequest.predicate = NSPredicate(format: "favorite = YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "favoriteIndex", ascending: true)]
        fetchRequest.fetchLimit = 3
        let favourites: [ForumMetadata]
        do {
            favourites = try managedObjectContext.fetch(fetchRequest)
        } catch {
            print("\(#function) fetch failed: \(error)")
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
        guard let url = URL(string: shortcutItem.type) else { return completionHandler(false) }
        let result = openAwfulURL(url)
        completionHandler(result)
    }
    
    fileprivate var _rootViewControllerStack: RootViewControllerStack?
    fileprivate var urlRouter: AwfulURLRouter?
    fileprivate var rootViewControllerStack: RootViewControllerStack {
        if let stack = _rootViewControllerStack { return stack }
        let stack = RootViewControllerStack(managedObjectContext: managedObjectContext)
        urlRouter = AwfulURLRouter(rootViewController: stack.rootViewController, managedObjectContext: managedObjectContext)
        _rootViewControllerStack = stack
        return stack
    }
    
    fileprivate lazy var loginViewController: LoginViewController! = {
        let loginVC = LoginViewController.newFromStoryboard()
        loginVC.completionBlock = { [weak self] (login) in
            guard let stack = self?.rootViewControllerStack else { return }
            self?.setRootViewController(stack.rootViewController, animated: true, completion: { [weak self] in
                self?.rootViewControllerStack.didAppear()
                self?.loginViewController = nil
            })
        }
        return loginVC
    }()
}

private extension AppDelegate {
    func setRootViewController(_ rootViewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let window = window else { return }
        UIView.transition(with: window, duration: animated ? 0.3 : 0, options: .transitionCrossDissolve, animations: { 
            window.rootViewController = rootViewController
            }) { (completed) in
                completion?()
        }
    }
    
    func themeDidChange() {
        window?.tintColor = Theme.currentTheme["tintColor"]
        window?.rootViewController?.themeDidChange()
    }
    
    @objc func settingsDidChange(_ notification: Notification) {
        guard let key = (notification as NSNotification).userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        if key == AwfulSettingsKeys.darkTheme.takeUnretainedValue() as String || key.hasPrefix("theme") {
            guard let window = window else { return }
            if let snapshot = window.snapshotView(afterScreenUpdates: false) {
                window.addSubview(snapshot)
                themeDidChange()
                
                UIView.transition(from: snapshot, to: window, duration: 0.2, options: [.transitionCrossDissolve, .showHideTransitionViews], completion: { (completed) in
                    snapshot.removeFromSuperview()
                })
            } else {
                themeDidChange()
            }
            
            
            
        } else if key == AwfulSettingsKeys.customBaseURL.takeUnretainedValue() as String {
            updateClientBaseURL()
        } else if key == AwfulSettingsKeys.autoDarkTheme.takeUnretainedValue() as String {
            NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: UIScreen.main)
        } else if key == AwfulSettingsKeys.autoThemeThreshold.takeUnretainedValue() as String {
            NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: UIScreen.main)
        }
    }
    
    @objc func brightnessDidChange(note: NSNotification) {
        if AwfulSettings.shared().autoDarkTheme {
            if let screen: UIScreen = note.object as? UIScreen {
                let threshold = CGFloat(AwfulSettings.shared().autoThemeThreshold / 100.0)
                // TODO: Replace threshold with user-set preference
                if screen.brightness > threshold && AwfulSettings.shared().darkTheme {
                    AwfulSettings.shared().darkTheme = false
                } else if screen.brightness <= threshold && !AwfulSettings.shared().darkTheme {
                    AwfulSettings.shared().darkTheme = true
                }
            }
        }
    }
    
    @objc func preferredContentSizeDidChange(_ notification: Notification) {
        themeDidChange()
    }
    
    func updateClientBaseURL() {
        let urlString = AwfulSettings.shared().customBaseURL ?? defaultBaseURLString
        guard var components = URLComponents(string: urlString) else { return }
        if components.scheme?.isEmpty ?? true {
            components.scheme = "http"
        }
        
        // Bare IP address is parsed by NSURLComponents as a path.
        if components.host == nil {
            components.host = components.path
            components.path = ""
        }
        
        AwfulForumsClient.shared().baseURL = components.url
    }
    
    func showPromptIfLoginCookieExpiresSoon() {
        guard let expiryDate = AwfulForumsClient.shared().loginCookieExpiryDate, expiryDate.timeIntervalSinceNow < loginCookieExpiringSoonThreshold
            else { return }
        let lastPromptDate = UserDefaults.standard.object(forKey: loginCookieLastExpiryPromptDateKey) as? Date ?? .distantFuture
        guard lastPromptDate.timeIntervalSinceNow < -loginCookieExpiryPromptFrequency else { return }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.title = "Login Expiring Soon"
        let dateString = DateFormatter.localizedString(from: expiryDate, dateStyle: .short, timeStyle: .none)
        alert.message = "Your login cookie expires on \(dateString)"
        alert.addActionWithTitle("OK") { 
            UserDefaults.standard.set(Date(), forKey: loginCookieLastExpiryPromptDateKey)
        }
        window?.rootViewController?.present(alert, animated: true, completion: nil)
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
            print("\(#function) error enumerating URL \(url.absoluteString)")
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
    
    for url in pendingDeletions {
        do {
            try fm.removeItem(at: url)
        } catch {
            print("\(#function) error deleting file at \(url.absoluteString)")
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

private let handoffVersion = 1

private func ignoreSilentSwitchWhenPlayingEmbeddedVideo() {
    do {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
    } catch {
        print("\(#function) error setting audio session category: \(error)")
    }
}

private let loginCookieExpiringSoonThreshold = days(7)
private let loginCookieLastExpiryPromptDateKey = "com.awfulapp.Awful.LastCookieExpiringPromptDate"
private let loginCookieExpiryPromptFrequency = days(2)

private let defaultBaseURLString = "https://forums.somethingawful.com"
