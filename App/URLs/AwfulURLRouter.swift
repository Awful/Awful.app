//  AwfulURLRouter.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import MRProgress
import UIKit

/// Translates URLs with the scheme "awful" into an appropriate shown screen.
final class AwfulURLRouter: NSObject {

    private let managedObjectContext: NSManagedObjectContext
    private let rootViewController: UIViewController
    
    /**
        - parameter rootViewController: The application's root view controller.
        - parameter managedObjectContext: The managed object context we use to find forums, threads, and posts.
     */
    init(rootViewController: UIViewController, managedObjectContext: NSManagedObjectContext) {
        self.rootViewController = rootViewController
        self.managedObjectContext = managedObjectContext
        super.init()
    }
    
    /// Show the screen appropriate for an "awful" URL.
    @discardableResult
    func route(_ route: AwfulRoute) -> Bool {
        switch route {
        case .bookmarks:
            return selectTopmostViewController(containingViewControllerOfClass: BookmarksTableViewController.self) != nil

        case let .forum(id: forumID):
            let key = ForumKey(forumID: forumID)
            guard let forum = Forum.existingObjectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as? Forum else { return false }
            return jumpToForum(forum)

        case .forumList:
            return selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil

        case .lepersColony:
            let rapSheetVC = RapSheetViewController(user: nil)
            rootViewController.present(rapSheetVC.enclosingNavigationController, animated: true)
            return true

        case let .message(id: messageID):
            guard let inbox = selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) else { return false }
            _ = inbox.navigationController?.popToViewController(inbox, animated: false)

            let key = PrivateMessageKey(messageID: messageID)
            if let message = PrivateMessage.objectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as? PrivateMessage {
                inbox.showMessage(message)
                return true
            }

            guard let rootView = rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, title: "Locating Message", mode: .indeterminate, animated: true)
            overlay?.tintColor = Theme.defaultTheme()["tintColor"]

            ForumsClient.shared.readPrivateMessage(identifiedBy: key)
                .done { message in
                    overlay?.dismiss(true, completion: {
                        inbox.showMessage(message)
                    })
                }
                .catch { error in
                    overlay?.titleLabelText = "Message Not Found"
                    overlay?.mode = .cross

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        overlay?.dismiss(true)
                    }
            }

            return true

        case .messagesList:
            return selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) != nil

        case let .post(id: postID, updateSeen):
            let key = PostKey(postID: postID)
            if let post = Post.existingObjectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as? Post,
               let thread = post.thread,
               post.page > 0
            {
                let postsVC = PostsPageViewController(thread: thread)
                var updateLastRead: Bool {
                    switch updateSeen {
                    case .noseen: return false
                    case .seen: return true
                    }
                }
                postsVC.loadPage(.specific(post.page), updatingCache: true, updatingLastReadPost: updateLastRead)
                postsVC.scrollPostToVisible(post)
                return showPostsViewController(postsVC)
            }

            guard let rootView = rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, title: "Locating Post", mode: .indeterminate, animated: true)
            overlay?.tintColor = Theme.defaultTheme()["tintColor"]

            var updateLastRead: Bool {
                switch updateSeen {
                case .noseen: return false
                case .seen: return true
                }
            }

            ForumsClient.shared.locatePost(id: key.postID, updateLastReadPost: updateLastRead)
                .done { [weak self] arg in
                    let (post, page) = arg
                    overlay?.dismiss(true, completion: {
                        guard
                            let self = self,
                            let thread = post.thread
                            else { return }
                        let postsVC = PostsPageViewController(thread: thread)
                        postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: true)
                        postsVC.scrollPostToVisible(post)
                        _ = self.showPostsViewController(postsVC)
                    })
                }
                .catch { error in
                    overlay?.titleLabelText = "Post Not Found"
                    overlay?.mode = .cross
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        overlay?.dismiss(true)
                    }
            }
            return true

        case let .profile(userID: userID):
            fetchUser(withUserID: userID) { (error, user) in
                if let error = error {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    self.rootViewController.present(alert, animated: true)
                    return
                }

                guard let user = user else { fatalError("no error should mean yes user") }
                let profileVC = ProfileViewController(user: user)
                self.rootViewController.present(profileVC.enclosingNavigationController, animated: true)
            }
            return true

        case let .rapSheet(userID: userID):
            fetchUser(withUserID: userID) { error, user in
                if let error = error {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    self.rootViewController.present(alert, animated: true)
                    return
                }

                guard let user = user else { fatalError("no error should mean yes user") }
                let rapSheetVC = RapSheetViewController(user: user)
                self.rootViewController.present(rapSheetVC.enclosingNavigationController, animated: true)
            }

            return true

        case .settings:
            return selectTopmostViewController(containingViewControllerOfClass: SettingsViewController.self) != nil

        case let .threadPage(threadID: threadID, page: page, updateSeen):
            return showThread(threadID, page: page, updateSeen: updateSeen)

        case let .threadPageSingleUser(threadID: threadID, userID: userID, page: page, updateSeen):
            return showThread(threadID, page: page, justPostsByUser: userID, updateSeen: updateSeen)
        }
    }
    
    private func jumpToForum(_ forum: Forum) -> Bool {
        if let threadsVC = rootViewController.firstDescendantOfType(ThreadsTableViewController.self),
           threadsVC.forum === forum
        {
            _ = threadsVC.navigationController?.popToViewController(threadsVC, animated: true)
            return selectTopmostViewController(containingViewControllerOfClass: ThreadsTableViewController.self) != nil
        }
        
        if let forumsVC = rootViewController.firstDescendantOfType(ForumsTableViewController.self) {
            _ = forumsVC.navigationController?.popToViewController(forumsVC, animated: false)
            forumsVC.openForum(forum, animated: false)
            return selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil
        }
        
        return false
    }
    
    private func selectTopmostViewController<VC: UIViewController>(
        containingViewControllerOfClass klass: VC.Type
    ) -> VC? {
        guard let
            splitVC = rootViewController.children.first as? UISplitViewController,
            let tabBarVC = splitVC.viewControllers.first as? UITabBarController
            else { return nil }
        for topmost in tabBarVC.viewControllers ?? [] {
            guard let match = topmost.firstDescendantOfType(VC.self) else { continue }
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
        let threadKey = ThreadKey(threadID: threadID)
        let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: managedObjectContext) as! AwfulThread
        let postsVC: PostsPageViewController
        if let userID = userID, !userID.isEmpty {
            let userKey = UserKey(userID: userID, username: nil)
            let user = User.objectForKey(objectKey: userKey, inManagedObjectContext: managedObjectContext) as! User
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
        guard let splitVC = rootViewController.children.first as? UISplitViewController else { return false }
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
    
    private func fetchUser(withUserID userID: String, completion: @escaping (Error?, User?) -> Void) {
        let key = UserKey(userID: userID, username: nil)
        if let user = User.existingObjectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as? User {
            completion(nil, user)
            return
        }
        
        ForumsClient.shared.profileUser(id: userID, username: nil)
            .done { completion(nil, $0.user) }
            .catch { completion($0, nil) }
    }
}
