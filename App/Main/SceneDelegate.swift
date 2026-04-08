//  SceneDelegate.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import CoreData
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SceneDelegate")

/// `NSUserActivity.userInfo` key carrying the vertical scroll fraction (Double, 0...1) for a
/// restored `PostsPageViewController` or `MessageViewController`.
private let restorationScrollFractionKey = "AwfulRestorationScrollFraction"

/// `NSUserActivity.userInfo` key carrying the `hiddenPosts` count for a restored
/// `PostsPageViewController`.
private let restorationHiddenPostsKey = "AwfulRestorationHiddenPosts"

/// `NSUserActivity.userInfo` key carrying the swipe-from-right-edge unpop stack for the visible
/// primary `NavigationController`, encoded as an array of `AwfulRoute.httpURL` strings.
private let restorationUnpopRoutesKey = "AwfulRestorationUnpopRoutes"

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
        } else {
            pendingRestorationActivity = session.stateRestorationActivity
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppDelegate.instance.rootViewControllerStackIfLoaded?.didAppear()

        guard !didProcessConnectionLaunch else { return }
        didProcessConnectionLaunch = true

        AppDelegate.instance.showPromptIfLoginCookieExpiresSoon()

        if let route = pendingLaunchRoute {
            pendingLaunchRoute = nil
            pendingRestorationActivity = nil
            DispatchQueue.main.async {
                AppDelegate.instance.open(route: route)
            }
        } else if let activity = pendingRestorationActivity, let route = activity.route {
            pendingRestorationActivity = nil
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
        guard let route = userActivity.route else { return }
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
        let activityType: String
        switch route {
        case .message:
            activityType = Handoff.ActivityType.readingMessage
        default:
            activityType = Handoff.ActivityType.browsingPosts
        }
        let activity = NSUserActivity(activityType: activityType)
        activity.route = route
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
