//  SceneDelegate.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import CoreData
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SceneDelegate")

/// Dedicated `NSUserActivity.activityType` for scene state restoration. Distinct from the
/// `Handoff.ActivityType` values so the restoration payload can carry any `AwfulRoute`
/// (including list tabs like `.bookmarks` / `.forumList`) without having to fit into Handoff's
/// narrower schema.
private let restorationActivityType = "com.awfulapp.Awful.activity.scene-restoration"

/// `NSUserActivity.userInfo` key carrying the restored primary route's `httpURL` string.
private let restorationPrimaryRouteKey = "AwfulRestorationPrimaryRoute"

/// `NSUserActivity.userInfo` key carrying the vertical scroll fraction (Double, 0...1) for a
/// restored `PostsPageViewController` or `MessageViewController`.
private let restorationScrollFractionKey = "AwfulRestorationScrollFraction"

/// `NSUserActivity.userInfo` key carrying the `hiddenPosts` count for a restored
/// `PostsPageViewController`.
private let restorationHiddenPostsKey = "AwfulRestorationHiddenPosts"

/// `NSUserActivity.userInfo` key carrying the swipe-from-right-edge unpop stack for the visible
/// primary `NavigationController`, encoded as an array of `AwfulRoute.httpURL` strings.
private let restorationUnpopRoutesKey = "AwfulRestorationUnpopRoutes"

/// `UserDefaults` key for a fallback copy of the scene's most recent restoration activity.
///
/// iOS only calls `stateRestorationActivity(for:)` when the scene is actually disconnected
/// (app-switcher kill, system memory reclaim). A plain Home-press keeps the scene connected,
/// so a subsequent crash or `Stop` from Xcode leaves `session.stateRestorationActivity` nil and
/// restoration silently fails. We work around this by snapshotting the same payload into
/// `UserDefaults` on every background transition, and falling back to it on cold launch.
private let restorationFallbackDefaultsKey = "AwfulSceneRestorationFallback"

/// Single window scene delegate. Adopting `UIScene` is what gives us iOS-managed state restoration
/// on iOS 13+: when the system kills our scene to reclaim memory, it will replay the
/// `NSUserActivity` we hand back from `stateRestorationActivity(for:)` on next launch, and we route
/// straight back to the previous thread/PM via the existing `AwfulURLRouter`.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var openCopiedURLController: OpenCopiedURLController?

    /// Held between `scene(_:willConnectTo:options:)` and `sceneDidBecomeActive` so routing
    /// happens after the root stack has finished its initial layout. A pending launch route from
    /// `connectionOptions` (deep link, shortcut, handoff) takes precedence over the restored
    /// activity from a previous scene session.
    private var pendingLaunchRoute: AwfulRoute?
    private var pendingRestorationActivity: NSUserActivity?

    private var didProcessConnectionLaunch = false

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.defaultTheme()["tintColor"]
        self.window = window

        AppDelegate.instance.window = window
        AppDelegate.instance.installInitialRootViewController(in: window)

        openCopiedURLController = OpenCopiedURLController(window: window) { route in
            AppDelegate.instance.open(route: route)
        }

        window.makeKeyAndVisible()

        if let urlContext = connectionOptions.urlContexts.first,
           let route = try? AwfulRoute(urlContext.url) {
            pendingLaunchRoute = route
        } else if let userActivity = connectionOptions.userActivities.first,
                  let route = userActivity.route {
            pendingLaunchRoute = route
        } else if let shortcutItem = connectionOptions.shortcutItem,
                  let url = URL(string: shortcutItem.type),
                  let route = try? AwfulRoute(url) {
            pendingLaunchRoute = route
        } else if let activity = session.stateRestorationActivity {
            pendingRestorationActivity = activity
        } else {
            pendingRestorationActivity = loadFallbackRestorationActivity()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Snapshot the current restoration activity to UserDefaults as a fallback for the cases
        // where iOS doesn't get a chance to call `stateRestorationActivity(for:)` itself (Xcode
        // Stop, crash while backgrounded). Scene disconnect will still go through the regular
        // path and overwrite whatever UIKit persists on `session.stateRestorationActivity`.
        if let activity = stateRestorationActivity(for: scene) {
            saveFallbackRestorationActivity(activity)
        } else {
            clearFallbackRestorationActivity()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Sync dark mode with system appearance on every foreground entry. The old
        // `applicationDidBecomeActive` path no longer fires under the scene lifecycle.
        AppDelegate.instance.automaticallyUpdateDarkModeEnabledIfNecessary()

        guard !didProcessConnectionLaunch else { return }
        didProcessConnectionLaunch = true

        // Only run the split-view display-mode fix-up on first activation after the scene
        // connects. Running it on every foregrounding can clobber a user-adjusted display mode.
        AppDelegate.instance.rootViewControllerStackIfLoaded?.didAppear()

        AppDelegate.instance.showPromptIfLoginCookieExpiresSoon()

        if let route = pendingLaunchRoute {
            pendingLaunchRoute = nil
            pendingRestorationActivity = nil
            DispatchQueue.main.async {
                AppDelegate.instance.open(route: route)
            }
        } else if let activity = pendingRestorationActivity {
            pendingRestorationActivity = nil
            clearFallbackRestorationActivity()
            guard let route = restoredRoute(from: activity) else {
                logger.debug("no route in restoration activity \(activity.activityType); skipping")
                return
            }
            logger.debug("restoring scene to \(activity.activityType)")
            let savedFraction = (activity.userInfo?[restorationScrollFractionKey] as? Double).map { CGFloat($0) }
            let savedHiddenPosts = activity.userInfo?[restorationHiddenPostsKey] as? Int
            let savedUnpopRoutes = (activity.userInfo?[restorationUnpopRoutesKey] as? [String])?
                .compactMap(URL.init(string:))
                .compactMap { try? AwfulRoute($0) } ?? []
            DispatchQueue.main.async {
                AppDelegate.instance.open(route: route)
                guard let stack = AppDelegate.instance.rootViewControllerStackIfLoaded else { return }
                if let topPosts = stack.topPostsPageViewController {
                    topPosts.prepareForRestoration(scrollFraction: savedFraction, hiddenPosts: savedHiddenPosts)
                } else if let topMessage = stack.topMessageViewController, let fraction = savedFraction {
                    topMessage.prepareForRestoration(scrollFraction: fraction)
                }
                if !savedUnpopRoutes.isEmpty, let primaryNav = stack.currentPrimaryNavigationController {
                    let context = AppDelegate.instance.managedObjectContext
                    let restoredVCs = savedUnpopRoutes.compactMap { makeUnpopViewController(for: $0, in: context) }
                    primaryNav.setUnpopStack(restoredVCs)
                }
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard ForumsClient.shared.isLoggedIn,
              let urlContext = URLContexts.first,
              let route = try? AwfulRoute(urlContext.url)
        else { return }
        AppDelegate.instance.open(route: route)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard ForumsClient.shared.isLoggedIn, let route = userActivity.route else { return }
        AppDelegate.instance.open(route: route)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let url = URL(string: shortcutItem.type),
              let route = try? AwfulRoute(url)
        else { return completionHandler(false) }
        AppDelegate.instance.open(route: route)
        completionHandler(true)
    }

    /// Returns an `NSUserActivity` wrapping the deepest visible `RestorableLocation`'s route,
    /// the current scroll fraction and hidden-posts count where applicable, and the
    /// swipe-from-right-edge unpop stack of the visible primary navigation. UIKit hands this back
    /// to us in `connectionOptions.session.stateRestorationActivity` after killing the scene for
    /// memory pressure, and we replay it through the existing `AwfulURLRouter`.
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let stack = AppDelegate.instance.rootViewControllerStackIfLoaded,
              let route = stack.currentRestorationRoute
        else { return nil }
        let activity = NSUserActivity(activityType: restorationActivityType)
        activity.addUserInfoEntries(from: [restorationPrimaryRouteKey: route.httpURL.absoluteString])
        if let topPosts = stack.topPostsPageViewController {
            var extras: [AnyHashable: Any] = [restorationHiddenPostsKey: topPosts.currentHiddenPosts]
            if let fraction = topPosts.currentScrollFraction {
                extras[restorationScrollFractionKey] = Double(fraction)
            }
            activity.addUserInfoEntries(from: extras)
        } else if let topMessage = stack.topMessageViewController,
                  let fraction = topMessage.currentScrollFraction {
            activity.addUserInfoEntries(from: [restorationScrollFractionKey: Double(fraction)])
        }
        let unpopURLs = stack.currentPrimaryNavigationController?.unpopRoutes.map(\.httpURL.absoluteString) ?? []
        if !unpopURLs.isEmpty {
            activity.addUserInfoEntries(from: [restorationUnpopRoutesKey: unpopURLs])
        }
        return activity
    }
}

/// Persists the given restoration activity's payload to `UserDefaults` as a fallback for
/// scenarios where iOS never calls `stateRestorationActivity(for:)` (Xcode Stop, crash in
/// background). Only plist-safe keys are written.
private func saveFallbackRestorationActivity(_ activity: NSUserActivity) {
    guard let userInfo = activity.userInfo else {
        UserDefaults.standard.removeObject(forKey: restorationFallbackDefaultsKey)
        return
    }
    var payload: [String: Any] = ["activityType": activity.activityType]
    for (key, value) in userInfo {
        guard let key = key as? String else { continue }
        payload[key] = value
    }
    UserDefaults.standard.set(payload, forKey: restorationFallbackDefaultsKey)
}

/// Reconstructs an `NSUserActivity` from the `UserDefaults` fallback, if present.
private func loadFallbackRestorationActivity() -> NSUserActivity? {
    guard let payload = UserDefaults.standard.dictionary(forKey: restorationFallbackDefaultsKey),
          let activityType = payload["activityType"] as? String
    else { return nil }
    let activity = NSUserActivity(activityType: activityType)
    var userInfo = payload
    userInfo.removeValue(forKey: "activityType")
    activity.addUserInfoEntries(from: userInfo)
    return activity
}

private func clearFallbackRestorationActivity() {
    UserDefaults.standard.removeObject(forKey: restorationFallbackDefaultsKey)
}

/// Decodes an `AwfulRoute` from a saved scene-restoration activity. Prefers the dedicated
/// `restorationPrimaryRouteKey` (which carries the route's `httpURL` string and covers every
/// `AwfulRoute` case), and falls back to the Handoff `NSUserActivity.route` getter so activities
/// surfaced via the handoff path still work.
private func restoredRoute(from activity: NSUserActivity) -> AwfulRoute? {
    if let urlString = activity.userInfo?[restorationPrimaryRouteKey] as? String,
       let url = URL(string: urlString),
       let route = try? AwfulRoute(url)
    {
        return route
    }
    return activity.route
}

/// Builds a fresh view controller for a route from the swipe-to-unpop restoration stack. Returns
/// nil for routes that can't be reconstructed standalone (e.g. `.post`, which needs a network
/// lookup), in which case that entry is silently dropped from the restored unpop stack.
private func makeUnpopViewController(for route: AwfulRoute, in context: NSManagedObjectContext) -> UIViewController? {
    switch route {
    case .bookmarks:
        return BookmarksTableViewController(managedObjectContext: context)
    case let .forum(id: forumID):
        let forum = Forum.objectForKey(objectKey: ForumKey(forumID: forumID), in: context)
        return ThreadsTableViewController(forum: forum)
    case let .message(id: messageID):
        let message = PrivateMessage.objectForKey(objectKey: PrivateMessageKey(messageID: messageID), in: context)
        return MessageViewController(privateMessage: message)
    case let .threadPage(threadID: threadID, page: page, _):
        let thread = AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), in: context)
        let postsVC = PostsPageViewController(thread: thread)
        postsVC.loadPage(page, updatingCache: false, updatingLastReadPost: true)
        return postsVC
    case let .threadPageSingleUser(threadID: threadID, userID: userID, page: page, _):
        let thread = AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), in: context)
        let user = User.objectForKey(objectKey: UserKey(userID: userID, username: nil), in: context)
        let postsVC = PostsPageViewController(thread: thread, author: user)
        postsVC.loadPage(page, updatingCache: false, updatingLastReadPost: true)
        return postsVC
    default:
        return nil
    }
}
