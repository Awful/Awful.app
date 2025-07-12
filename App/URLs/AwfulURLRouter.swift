//  AwfulURLRouter.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import MRProgress
import UIKit

/// Translates URLs with the scheme "awful" into an appropriate shown screen.
struct AwfulURLRouter {

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private let managedObjectContext: NSManagedObjectContext
    private let rootViewController: UIViewController?
    weak var coordinator: (any MainCoordinator)?
    
    /**
        - parameter rootViewController: The application's root view controller (optional for SwiftUI-only mode).
        - parameter managedObjectContext: The managed object context we use to find forums, threads, and posts.
     */
    init(rootViewController: UIViewController?, managedObjectContext: NSManagedObjectContext) {
        self.rootViewController = rootViewController
        self.managedObjectContext = managedObjectContext
    }
    
    /// Show the screen appropriate for an "awful" URL.
    @discardableResult
    func route(_ route: AwfulRoute) -> Bool {
        
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        switch route {
        case .bookmarks:
            if let coordinator = coordinator {
                coordinator.navigateToTab(.bookmarks)
                return true
            }
            return selectTopmostViewController(containingViewControllerOfClass: BookmarksTableViewController.self) != nil

        case let .forum(id: forumID):
            if let coordinator = coordinator {
                return coordinator.navigateToForumWithID(forumID)
            }
            let key = ForumKey(forumID: forumID)
            guard let forum = Forum.existingObjectForKey(objectKey: key, in: managedObjectContext) else { return false }
            return jumpToForum(forum)

        case .forumList:
            if let coordinator = coordinator {
                coordinator.navigateToTab(.forums)
                return true
            }
            return selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil

        case .lepersColony:
            if let coordinator = coordinator {
                coordinator.navigateToTab(.lepers)
                return true
            }
            guard let rootViewController = rootViewController else { return false }
            let rapSheetVC = RapSheetViewController(user: nil)
            rootViewController.present(rapSheetVC.enclosingNavigationController, animated: true)
            return true

        case let .message(id: messageID):
            if let coordinator = coordinator {
                return coordinator.navigateToMessageWithID(messageID)
            }
            guard let inbox = selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) else { return false }
            _ = inbox.navigationController?.popToViewController(inbox, animated: false)

            let key = PrivateMessageKey(messageID: messageID)
            if let message = PrivateMessage.existingObjectForKey(objectKey: key, in: managedObjectContext) {
                inbox.showMessage(message)
                return true
            }

            guard let rootViewController = rootViewController,
                  let rootView = rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, title: "Locating Message", mode: .indeterminate, animated: true)!
            overlay.tintColor = Theme.defaultTheme()["tintColor"]

            Task { @MainActor in
                do {
                    let message = try await ForumsClient.shared.readPrivateMessage(identifiedBy: key)
                    overlay.dismiss(true, completion: {
                        inbox.showMessage(message)
                    })
                } catch {
                    overlay.titleLabelText = "Message Not Found"
                    overlay.mode = .cross
                    try? await Task.sleep(timeInterval: 0.7)
                    overlay.dismiss(true)
                }
            }
            return true

        case .messagesList:
            if let coordinator = coordinator {
                coordinator.navigateToTab(.messages)
                return true
            }
            return selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) != nil

        case let .post(id: postID, updateSeen):
            print("🔗 AwfulURLRouter: Handling .post route with postID: \(postID)")
            if let coordinator = coordinator {
                print("🔗 AwfulURLRouter: Calling coordinator.navigateToPostWithID(\(postID))")
                let result = coordinator.navigateToPostWithID(postID)
                print("🔗 AwfulURLRouter: coordinator.navigateToPostWithID returned: \(result)")
                return result
            }
            let key = PostKey(postID: postID)

            var updateLastRead: Bool {
                switch updateSeen {
                case .noseen: return false
                case .seen: return true
                }
            }
            
            if let post = Post.existingObjectForKey(objectKey: key, in: managedObjectContext),
               let thread = post.thread,
               post.page > 0
            {
                let postsVC = PostsPageViewController(thread: thread)
                postsVC.jumpToPostIDAfterLoading = post.postID
                postsVC.loadPage(.specific(post.page), updatingCache: true, updatingLastReadPost: updateLastRead)
                return showPostsViewController(postsVC)
            }

            guard let rootViewController = rootViewController,
                  let rootView = rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, title: "Locating Post", mode: .indeterminate, animated: true)!
            overlay.tintColor = Theme.defaultTheme()["tintColor"]

            Task { @MainActor in
                do {
                    let (post, page) = try await ForumsClient.shared.locatePost(id: key.postID, updateLastReadPost: updateLastRead)
                    overlay.dismiss(true) {
                        guard let thread = post.thread else { return }

                        if let coordinator = self.coordinator {
                            // TODO: This doesn't scroll to the post.
                            coordinator.navigateToThread(thread, page: page)
                        } else {
                            let postsVC = PostsPageViewController(thread: thread)
                            postsVC.jumpToPostIDAfterLoading = post.postID
                            postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: true)
                            _ = self.showPostsViewController(postsVC)
                        }
                    }
                } catch {
                    overlay.titleLabelText = "Post Not Found"
                    overlay.mode = .cross
                    try? await Task.sleep(timeInterval: 3)
                    overlay.dismiss(true)
                }
            }
            return true

        case let .profile(userID: userID):
            if let coordinator = coordinator {
                coordinator.presentUserProfile(userID: userID)
                return true
            }
            guard let rootViewController = rootViewController else { return false }
            Task { @MainActor in
                do {
                    let user = try await fetchUser(withUserID: userID)
                    let profileVC = ProfileViewController(user: user)
                    rootViewController.present(profileVC.enclosingNavigationController, animated: true)
                } catch {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    rootViewController.present(alert, animated: true)
                }
            }
            return true

        case let .rapSheet(userID: userID):
            if let coordinator = coordinator {
                coordinator.presentRapSheet(userID: userID)
                return true
            }
            guard let rootViewController = rootViewController else { return false }
            Task { @MainActor in
                do {
                    let user = try await fetchUser(withUserID: userID)
                    let rapSheetVC = RapSheetViewController(user: user)
                    rootViewController.present(rapSheetVC.enclosingNavigationController, animated: true)
                } catch {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    rootViewController.present(alert, animated: true)
                }
            }
            return true

        case .settings:
            if let coordinator = coordinator {
                coordinator.navigateToTab(.settings)
                return true
            }
            return selectTopmostViewController(containingViewControllerOfClass: SettingsViewController.self) != nil

        case let .threadPage(threadID: threadID, page: page, updateSeen):
            if let coordinator = coordinator {
                return coordinator.navigateToThreadWithID(threadID, page: page, author: nil)
            }
            return showThread(threadID, page: page, updateSeen: updateSeen)

        case let .threadPageSingleUser(threadID: threadID, userID: userID, page: page, updateSeen):
            if let coordinator = coordinator {
                // Find the author user
                let userKey = UserKey(userID: userID, username: nil)
                let author = User.existingObjectForKey(objectKey: userKey, in: managedObjectContext)
                return coordinator.navigateToThreadWithID(threadID, page: page, author: author)
            }
            return showThread(threadID, page: page, justPostsByUser: userID, updateSeen: updateSeen)
        }
    }
    
    private func jumpToForum(_ forum: Forum) -> Bool {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let rootViewController = rootViewController else { return false }
        
        if let threadsVC = rootViewController.firstDescendant(ofType: ThreadsTableViewController.self),
           threadsVC.forum === forum
        {
            _ = threadsVC.navigationController?.popToViewController(threadsVC, animated: true)
            return selectTopmostViewController(containingViewControllerOfClass: ThreadsTableViewController.self) != nil
        }
        
        if let forumsVC = rootViewController.firstDescendant(ofType: ForumsTableViewController.self) {
            _ = forumsVC.navigationController?.popToViewController(forumsVC, animated: false)
            forumsVC.openForum(forum, animated: false)
            return selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil
        }
        
        return false
    }
    
    private func selectTopmostViewController<VC: UIViewController>(
        containingViewControllerOfClass klass: VC.Type
    ) -> VC? {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let rootViewController = rootViewController,
              let splitVC = rootViewController.children.first as? UISplitViewController,
              let tabBarVC = splitVC.viewControllers.first as? UITabBarController
              else { return nil }
        for topmost in tabBarVC.viewControllers ?? [] {
            guard let match = topmost.firstDescendant(ofType: VC.self) else { continue }
            tabBarVC.selectedViewController = topmost
            splitVC.showPrimaryViewController()
            return match
        }
        return nil
    }
    
    private func showThread(
        _ threadID: String,
        page: ThreadPage,
        justPostsByUser userID: String? = nil,
        updateSeen: AwfulRoute.UpdateSeen
    ) -> Bool {
        if let coordinator = coordinator {
            let threadKey = ThreadKey(threadID: threadID)
            let thread = AwfulThread.objectForKey(objectKey: threadKey, in: managedObjectContext)
            
            var author: User?
            if let userID = userID, !userID.isEmpty {
                let userKey = UserKey(userID: userID, username: nil)
                author = User.objectForKey(objectKey: userKey, in: managedObjectContext)
            }
            
            // This doesn't handle updateSeen yet.
            coordinator.navigateToThread(thread, page: page, author: author)
            
            return true
        }
        
        let threadKey = ThreadKey(threadID: threadID)
        let thread = AwfulThread.objectForKey(objectKey: threadKey, in: managedObjectContext) 
        let postsVC: PostsPageViewController
        if let userID = userID, !userID.isEmpty {
            let userKey = UserKey(userID: userID, username: nil)
            let user = User.objectForKey(objectKey: userKey, in: managedObjectContext) 
            postsVC = PostsPageViewController(thread: thread, author: user)
        } else {
            postsVC = PostsPageViewController(thread: thread)
        }
        
        try! managedObjectContext.save()

        var updateLastRead: Bool {
            switch updateSeen {
            case .noseen: return false
            case .seen: return true
            }
        }
        postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: updateLastRead)
        
        return showPostsViewController(postsVC)
    }
    
    private func showPostsViewController(_ postsVC: PostsPageViewController) -> Bool {
        postsVC.restorationIdentifier = "Posts from URL"
        
        // Showing a posts view controller as a result of opening a URL is not the same as simply showing a detail view controller. We want to push it on to an existing navigation stack. Which one depends on how the split view is currently configured.
        let targetNav: UINavigationController
        guard let rootViewController = rootViewController,
              let splitVC = rootViewController.children.first as? UISplitViewController else { return false }
        if splitVC.viewControllers.count == 2 {
            targetNav = splitVC.viewControllers[1] as! UINavigationController
        } else {
            guard let tabBarVC = splitVC.viewControllers[0] as? UITabBarController else { return false }
            targetNav = tabBarVC.selectedViewController as! UINavigationController
        }
        
        // If the detail view controller is empty, showing the posts view controller actually is as simple as showing a detail view controller, and we can exit early.
        if targetNav.topViewController is EmptyViewController {
            splitVC.showDetailViewController(postsVC, sender: self)
            return true
        }
        
        // Posts view controllers by default hide the bottom bar when pushed. This moves the tab bar controller's tab bar out of the way, making room for the toolbar. However, if some earlier posts view controller has already done this for us, and we went ahead oblivious, we would hide our own toolbar!
        if targetNav.topViewController is PostsPageViewController {
            postsVC.hidesBottomBarWhenPushed = false
        }
        
        targetNav.pushViewController(postsVC, animated: true)
        return true
    }
    
    private func fetchUser(withUserID userID: String) async throws -> User {
        let key = UserKey(userID: userID, username: nil)
        if let user = User.existingObjectForKey(objectKey: key, in: managedObjectContext) {
            return user
        }
        
        return try await ForumsClient.shared.profileUser(.userID(userID)).user
    }
}
