//  AppDelegate.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import AVFoundation
import AwfulCore
import GRMustache
import Smilies
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private(set) static var instance: AppDelegate!
    private var dataStore: DataStore!
    var managedObjectContext: NSManagedObjectContext { return dataStore.mainManagedObjectContext }
    var window: UIWindow?
    
    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        AppDelegate.instance = self
        
        GRMustache.preventNSUndefinedKeyExceptionAttack()
        
        AwfulSettings.sharedSettings().registerDefaults()
        AwfulSettings.sharedSettings().migrateOldSettings()
        
        let appSupport = try! NSFileManager.defaultManager().URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let storeURL = appSupport.URLByAppendingPathComponent("CachedForumData", isDirectory: true)
        let modelURL = NSBundle(forClass: DataStore.self).URLForResource("Awful", withExtension: "momd")!
        dataStore = DataStore(storeDirectoryURL: storeURL, modelURL: modelURL)
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), removeOldDataStores)
        
        AwfulForumsClient.sharedClient().managedObjectContext = managedObjectContext
        updateClientBaseURL()
        AwfulForumsClient.sharedClient().didRemotelyLogOutBlock = { [weak self] in
            self?.logOut()
        }
        
        AFNetworkActivityIndicatorManager.sharedManager().enabled = true
        
        NSURLCache.setSharedURLCache(NSURLCache(memoryCapacity: megabytes(5), diskCapacity: megabytes(50), diskPath: nil))
        
        let protocols: [AnyClass] = [ImageURLProtocol.self, MinusFixURLProtocol.self, ResourceURLProtocol.self, WaffleimagesURLProtocol.self]
        for proto in protocols {
            NSURLProtocol.registerClass(proto)
        }
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window?.tintColor = Theme.currentTheme["tintColor"]
        
        if AwfulForumsClient.sharedClient().loggedIn {
            setRootViewController(rootViewControllerStack.rootViewController, animated: false, completion: nil)
        } else {
            setRootViewController(loginViewController.enclosingNavigationController, animated: false, completion: nil)
        }
        
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // Don't want to lazily create it now.
        _rootViewControllerStack?.didAppear()
        
        ignoreSilentSwitchWhenPlayingEmbeddedVideo()
        
        showPromptIfLoginCookieExpiresSoon()
        
        NewMessageChecker.sharedChecker.refreshIfNecessary()
        PostsViewExternalStylesheetLoader.sharedLoader.refreshIfNecessary()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(settingsDidChange), name: AwfulSettingsDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(preferredContentSizeDidChange), name: UIContentSizeCategoryDidChangeNotification, object: nil)
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(false)
        
        updateShortcutItems()
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        SmilieKeyboardSetIsAwfulAppActive(true)
        
        guard AwfulForumsClient.sharedClient().loggedIn else { return }
        guard let
            url = UIPasteboard.generalPasteboard().awful_URL,
            let awfulURL = url.awfulURL
            else { return }
        for urlTypes in NSBundle.mainBundle().infoDictionary?["CFBundleURLTypes"] as? [[String: AnyObject]] ?? [] {
            for urlScheme in urlTypes["CFBundleURLSchemes"] as? [String] ?? [] {
                if urlScheme.caseInsensitiveCompare(url.scheme) == .OrderedSame {
                    return
                }
            }
        }
        
        guard AwfulSettings.sharedSettings().lastOfferedPasteboardURL != url.absoluteString else { return }
        AwfulSettings.sharedSettings().lastOfferedPasteboardURL = url.absoluteString
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
        alert.message = "Would you like to open this URL in Awful?\n\n\(url.absoluteString)"
        alert.addCancelActionWithHandler(nil)
        alert.addActionWithTitle("Open", handler: { (action) in
            self.openAwfulURL(awfulURL)
        })
        window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func application(application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return AwfulForumsClient.sharedClient().loggedIn
    }
    
    func application(application: UIApplication, willEncodeRestorableStateWithCoder coder: NSCoder) {
        coder.encodeInteger(currentInterfaceVersion.rawValue, forKey: interfaceVersionKey)
    }
    
    func application(application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        guard AwfulForumsClient.sharedClient().loggedIn else { return false }
        return coder.decodeIntegerForKey(interfaceVersionKey) == currentInterfaceVersion.rawValue
    }
    
    func application(application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        guard let identifierComponents = identifierComponents as? [String] else { return nil }
        return rootViewControllerStack.viewControllerWithRestorationIdentifierPath(identifierComponents)
    }
    
    func application(application: UIApplication, didDecodeRestorableStateWithCoder coder: NSCoder) {
        try! managedObjectContext.save()
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        guard AwfulForumsClient.sharedClient().loggedIn else { return false }
        if ["awfulhttp", "awfulhttps"].contains(url.scheme.lowercaseString) {
            guard let awfulURL = url.awfulURL else { return false }
            return openAwfulURL(awfulURL)
        }
        return openAwfulURL(url)
    }
    
    func application(application: UIApplication, didUpdateUserActivity userActivity: NSUserActivity) {
        // Bit of future-proofing.
        userActivity.addUserInfoEntriesFromDictionary([Handoff.InfoVersionKey: handoffVersion])
    }
    
    func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        guard let
            awfulURL = userActivity.awfulURL,
            let router = urlRouter
            else { return false }
        router.route(awfulURL)
        return true
    }
    
    func logOut() {
        // Logging out doubles as an "empty cache" button.
        let cookieJar = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in cookieJar.cookies ?? [] {
            cookieJar.deleteCookie(cookie)
        }
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        
        AwfulSettings.sharedSettings().reset()
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
    func openAwfulURL(url: NSURL) -> Bool {
        guard let router = urlRouter else { return false }
        return router.route(url)
    }
    
    private func updateShortcutItems() {
        guard urlRouter != nil else {
            UIApplication.sharedApplication().shortcutItems = []
            return
        }
        
        var shortcutItems: [UIApplicationShortcutItem] = []
        
        // Add a shortcut to quick-open to bookmarks.
        // For whatever reason, the first shortcut item is the one closest to the bottom.
        let bookmarksImage = UIApplicationShortcutIcon(templateImageName: "bookmarks")
        shortcutItems.append(UIApplicationShortcutItem(type: "awful://bookmarks", localizedTitle: "Bookmarks", localizedSubtitle: nil, icon: bookmarksImage, userInfo: nil))
        
        // Add a shortcut for favorited forums, in the order they appear in the list.
        let fetchRequest = NSFetchRequest(entityName: ForumMetadata.entityName())
        fetchRequest.predicate = NSPredicate(format: "favorite = YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "favoriteIndex", ascending: true)]
        fetchRequest.fetchLimit = 3
        let favourites: [ForumMetadata]
        do {
            favourites = try managedObjectContext.executeFetchRequest(fetchRequest) as! [ForumMetadata]
        } catch {
            print("\(#function) fetch failed: \(error)")
            return
        }
        let favouritesIcon = UIApplicationShortcutIcon(templateImageName: "star-off")
        for metadata in favourites.lazy.reverse() {
            let urlString = "awful://forums/\(metadata.forum.forumID)"
            // I wish we could get the forum's alt-text sanely somehow :(
            shortcutItems.append(UIApplicationShortcutItem(type: urlString, localizedTitle: metadata.forum.name ?? "", localizedSubtitle: nil, icon: favouritesIcon, userInfo: nil))
        }
        
        UIApplication.sharedApplication().shortcutItems = shortcutItems
    }
    
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        guard let url = NSURL(string: shortcutItem.type) else { return completionHandler(false) }
        let result = openAwfulURL(url)
        completionHandler(result)
    }
    
    private var _rootViewControllerStack: RootViewControllerStack?
    private var urlRouter: AwfulURLRouter?
    private var rootViewControllerStack: RootViewControllerStack {
        if let stack = _rootViewControllerStack { return stack }
        let stack = RootViewControllerStack(managedObjectContext: managedObjectContext)
        urlRouter = AwfulURLRouter(rootViewController: stack.rootViewController, managedObjectContext: managedObjectContext)
        _rootViewControllerStack = stack
        return stack
    }
    
    private lazy var loginViewController: LoginViewController! = {
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
    func setRootViewController(rootViewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let window = window else { return }
        UIView.transitionWithView(window, duration: animated ? 0.3 : 0, options: .TransitionCrossDissolve, animations: { 
            window.rootViewController = rootViewController
            }) { (completed) in
                completion?()
        }
    }
    
    func themeDidChange() {
        window?.tintColor = Theme.currentTheme["tintColor"]
        window?.rootViewController?.themeDidChange()
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        if key == AwfulSettingsKeys.darkTheme.takeUnretainedValue() || key.hasPrefix("theme") {
            guard let window = window else { return }
            let snapshot = window.snapshotViewAfterScreenUpdates(false)
            window.addSubview(snapshot)
            
            themeDidChange()
            
            UIView.transitionFromView(snapshot, toView: window, duration: 0.2, options: [.TransitionCrossDissolve, .ShowHideTransitionViews], completion: { (completed) in
                snapshot.removeFromSuperview()
            })
        } else if key == AwfulSettingsKeys.customBaseURL.takeUnretainedValue() {
            updateClientBaseURL()
        }
    }
    
    @objc private func preferredContentSizeDidChange(notification: NSNotification) {
        themeDidChange()
    }
    
    private func updateClientBaseURL() {
        let urlString = AwfulSettings.sharedSettings().customBaseURL ?? defaultBaseURLString
        guard let components = NSURLComponents(string: urlString) else { return }
        if components.scheme?.isEmpty ?? true {
            components.scheme = "http"
        }
        
        // Bare IP address is parsed by NSURLComponents as a path.
        if components.path != nil && components.host == nil {
            components.host = components.path
            components.path = nil
        }
        
        AwfulForumsClient.sharedClient().baseURL = components.URL
    }
    
    private func showPromptIfLoginCookieExpiresSoon() {
        guard let expiryDate = AwfulForumsClient.sharedClient().loginCookieExpiryDate, expiryDate.timeIntervalSinceNow < loginCookieExpiringSoonThreshold
            else { return }
        let lastPromptDate = NSUserDefaults.standardUserDefaults().objectForKey(loginCookieLastExpiryPromptDateKey) as? NSDate ?? .distantFuture()
        guard lastPromptDate.timeIntervalSinceNow < -loginCookieExpiryPromptFrequency else { return }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
        alert.title = "Login Expiring Soon"
        let dateString = NSDateFormatter.localizedStringFromDate(expiryDate, dateStyle: .ShortStyle, timeStyle: .NoStyle)
        alert.message = "Your login cookie expires on \(dateString)"
        alert.addActionWithTitle("OK") { 
            NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: loginCookieLastExpiryPromptDateKey)
        }
        window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
}

private func removeOldDataStores() {
    // Obsolete data stores should be cleaned up so we're not wasting space.
    let fm = NSFileManager.defaultManager()
    var pendingDeletions: [NSURL] = []
    
    // The Documents directory is pre-Awful 3.0. It was unsuitable because it was not user-managed data.
    // The Caches directory was used through Awful 3.1. It was unsuitable once user data was stored in addition to cached presentation data.
    // Both stores were under the same filename.
    let documents = try! fm.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
    let caches = try! fm.URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
    for directory in [documents, caches] {
        guard let enumerator = fm.enumeratorAtURL(directory, includingPropertiesForKeys: nil, options: .SkipsSubdirectoryDescendants, errorHandler: { (url, error) -> Bool in
            print("\(#function) error enumerating URL \(url.absoluteString)")
            return true
        }) else { continue }
        for url in enumerator {
            // Check for prefix, not equality, as there could be associated files (SQLite indexes or logs) that should also disappear.
            if let
                url = url as? NSURL,
                let filename = url.lastPathComponent, filename.hasPrefix("AwfulData.sqlite")
            {
                pendingDeletions.append(url)
            }
        }
    }
    
    for url in pendingDeletions {
        do {
            try fm.removeItemAtURL(url)
        } catch {
            print("\(#function) error deleting file at \(url.absoluteString)")
        }
    }
}

/// Returns the number of bytes in the passed-in number of megabytes.
private func megabytes(mb: Int) -> Int {
    return mb * 1024 * 1024
}

private func days(days: Int) -> NSTimeInterval {
    return NSTimeInterval(days) * 24 * 60 * 60
}

// Value is an InterfaceVersion integer. Encoded when preserving state, and possibly useful for determining whether to decode state or to somehow migrate the preserved state.
private let interfaceVersionKey = "AwfulInterfaceVersion"

private enum InterfaceVersion: Int {
    /// Interface for Awful 2, the version that runs on iOS 7. On iPhone, a basement-style menu is the root view controller. On iPad, a custom split view controller is the root view controller, and it hosts a vertical tab bar controller as its primary view controller.
    case Version2
    
    /// Interface for Awful 3, the version that runs on iOS 8. The primary view controller is a UISplitViewController on both iPhone and iPad.
    case Version3
}

private let currentInterfaceVersion: InterfaceVersion = .Version3

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
