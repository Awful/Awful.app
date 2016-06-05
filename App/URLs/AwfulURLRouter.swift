//  AwfulURLRouter.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import JLRoutes
import MRProgress
import UIKit

/// Translates URLs with the scheme "awful" into an appropriate shown screen.
final class AwfulURLRouter: NSObject {
    private let rootViewController: UIViewController
    private let managedObjectContext: NSManagedObjectContext
    
    /**
        - parameter rootViewController: The application's root view controller.
        - parameter managedObjectContext: The managed object context we use to find forums, threads, and posts.
     */
    init(rootViewController: UIViewController, managedObjectContext: NSManagedObjectContext) {
        self.rootViewController = rootViewController
        self.managedObjectContext = managedObjectContext
        super.init()
    }
    
    private lazy var routes: JLRoutes = {
        let routes = JLRoutes()
        
        routes.addRoute("/forums/:forumID", handler: { [weak self] (parameters) -> Bool in
            guard let
                forumID = parameters["forumID"] as? String,
                context = self?.managedObjectContext
                else { return false }
            let key = ForumKey(forumID: forumID)
            guard let forum = Forum.existingObjectForKey(key, inManagedObjectContext: context) as? Forum else { return false }
            return self?.jumpToForum(forum) ?? false
        })
        
        routes.addRoute("/forums", handler: { [weak self] (parameters) -> Bool in
            return self?.selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil
        })
        
        routes.addRoute("/threads/:threadID/pages/:page", handler: { [weak self] (parameters) -> Bool in
            return self?.showThread(withParameters: parameters) ?? false
        })
        
        routes.addRoute("/threads/:threadID", handler: { [weak self] (parameters) -> Bool in
            return self?.showThread(withParameters: parameters) ?? false
        })
        
        routes.addRoute("/posts/:postID", handler: { [weak self] (parameters) -> Bool in
            guard let postID = parameters["postID"] as? String else { return false }
            let key = PostKey(postID: postID)
            guard let context = self?.managedObjectContext else { return false }
            if let
                post = Post.existingObjectForKey(key, inManagedObjectContext: context) as? Post,
                thread = post.thread
                where post.page > 0
            {
                let postsVC = PostsPageViewController(thread: thread)
                postsVC.loadPage(post.page, updatingCache: true, updatingLastReadPost: true)
                postsVC.scrollPostToVisible(post)
                return self?.showPostsViewController(postsVC) ?? false
            }
            
            guard let rootView = self?.rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAddedTo(rootView, title: "Locating Post", mode: .Indeterminate, animated: true)
            overlay.tintColor = Theme.currentTheme["tintColor"]
            
            AwfulForumsClient.sharedClient().locatePostWithID(key.postID, andThen: { [weak self] (error, post, page) in
                if let error = error {
                    overlay.titleLabelText = "Post Not Found"
                    overlay.mode = .Cross
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.7 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                        overlay.dismiss(true)
                    }
                    return
                }
                
                overlay.dismiss(true, completion: {
                    guard let thread = post.thread else { return }
                    let postsVC = PostsPageViewController(thread: thread)
                    postsVC.loadPage(page.rawValue, updatingCache: true, updatingLastReadPost: true)
                    postsVC.scrollPostToVisible(post)
                    self?.showPostsViewController(postsVC)
                    
                    try! context.save()
                })
            })
            return true
        })
        
        routes.addRoute("/messages/:messageID", handler: { [weak self] (parameters) -> Bool in
            guard let inbox = self?.selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) else { return false }
            inbox.navigationController?.popToViewController(inbox, animated: false)
            
            guard let messageID = parameters["messageID"] as? String else { return false }
            let key = PrivateMessageKey(messageID: messageID)
            guard let context = self?.managedObjectContext else { return false }
            if let message = PrivateMessage.objectForKey(key, inManagedObjectContext: context) as? PrivateMessage {
                inbox.showMessage(message)
                return true
            }
            
            guard let rootView = self?.rootViewController.view else { return false }
            let overlay = MRProgressOverlayView.showOverlayAddedTo(rootView, title: "Locating Message", mode: .Indeterminate, animated: true)
            overlay.tintColor = Theme.currentTheme["tintColor"]
            
            AwfulForumsClient.sharedClient().readPrivateMessageWithKey(key, andThen: { [weak self] (error, message) in
                if let error = error {
                    overlay.titleLabelText = "Message Not Found"
                    overlay.mode = .Cross
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.7 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { 
                        overlay.dismiss(true)
                    })
                    return
                }
                
                overlay.dismiss(true, completion: {
                    inbox.showMessage(message)
                })
            })
            return true
        })
        
        routes.addRoute("/messages", handler: { [weak self] (parameters) -> Bool in
            return self?.selectTopmostViewController(containingViewControllerOfClass: MessageListViewController.self) != nil
        })
        
        routes.addRoute("/bookmarks", handler: { [weak self] (parameters) -> Bool in
            return self?.selectTopmostViewController(containingViewControllerOfClass: BookmarksTableViewController.self) != nil
        })
        
        routes.addRoute("/settings", handler: { [weak self] (parameters) -> Bool in
            return self?.selectTopmostViewController(containingViewControllerOfClass: SettingsViewController.self) != nil
        })
        
        routes.addRoute("/users/:userID", handler: { [weak self] (parameters) -> Bool in
            guard let userID = parameters["userID"] as? String else { return false }
            self?.fetchUser(withUserID: userID) { (error, user) in
                if let error = error {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    self?.rootViewController.presentViewController(alert, animated: true, completion: nil)
                    return
                }

                guard let user = user else { fatalError("no error should mean yes user") }
                let profileVC = ProfileViewController(user: user)
                self?.rootViewController.presentViewController(profileVC.enclosingNavigationController, animated: true, completion: nil)
            }
            return true
        })
        
        routes.addRoute("/banlist/:userID", handler: { [weak self] (parameters) -> Bool in
            guard let userID = parameters["userID"] as? String else { return false }
            self?.fetchUser(withUserID: userID) { (error, user) in
                if let error = error {
                    let alert = UIAlertController(title: "Could Not Find User", error: error)
                    self?.rootViewController.presentViewController(alert, animated: true, completion: nil)
                    return
                }
                
                guard let user = user else { fatalError("no error should mean yes user") }
                let rapSheetVC = RapSheetViewController(user: user)
                self?.rootViewController.presentViewController(rapSheetVC.enclosingNavigationController, animated: true, completion: nil)
            }
            
            return true
        })
        
        routes.addRoute("/banlist", handler: { [weak self] (parameters) -> Bool in
            let rapSheetVC = RapSheetViewController(user: nil)
            self?.rootViewController.presentViewController(rapSheetVC.enclosingNavigationController, animated: true, completion: nil)
            return true
        })
        
        return routes
    }()
    
    /**
        Show the screen appropriate for an "awful" URL.
     
        - parameter url: A URL with the scheme "awful".
     
        - returns: `true` if the URL was successfully routed, otherwise `false`.
     */
    func route(url: NSURL) -> Bool {
        guard url.scheme.caseInsensitiveCompare("awful") == .OrderedSame else { return false }
        return routes.routeURL(url)
    }
    
    private func jumpToForum(forum: Forum) -> Bool {
        if let
            threadsVC = rootViewController.firstDescendantOfType(ThreadsTableViewController.self)
            where threadsVC.forum == forum
        {
            threadsVC.navigationController?.popToViewController(threadsVC, animated: true)
            return selectTopmostViewController(containingViewControllerOfClass: ThreadsTableViewController.self) != nil
        }
        
        if let forumsVC = rootViewController.firstDescendantOfType(ForumsTableViewController.self) {
            forumsVC.navigationController?.popToViewController(forumsVC, animated: false)
            forumsVC.openForum(forum, animated: false)
            return selectTopmostViewController(containingViewControllerOfClass: ForumsTableViewController.self) != nil
        }
        
        return false
    }
    
    private func selectTopmostViewController<T: UIViewController>(containingViewControllerOfClass klass: T.Type) -> T? {
        guard let
            splitVC = rootViewController as? UISplitViewController,
            tabBarVC = splitVC.viewControllers.first as? UITabBarController
            else { return nil }
        for topmost in tabBarVC.viewControllers ?? [] {
            guard let match = topmost.firstDescendantOfType(T) else { continue }
            tabBarVC.selectedViewController = topmost
            splitVC.showPrimaryViewController()
            return match
        }
        return nil
    }
    
    private func showThread(withParameters parameters: [NSObject: AnyObject]) -> Bool {
        guard let threadID = parameters["threadID"] as? String else { return false }
        let threadKey = ThreadKey(threadID: threadID)
        let thread = Thread.objectForKey(threadKey, inManagedObjectContext: managedObjectContext) as! Thread
        let userID = parameters["userid"] as? String
        let postsVC: PostsPageViewController
        if let userID = userID where !userID.isEmpty {
            let userKey = UserKey(userID: userID, username: nil)
            let user = User.objectForKey(userKey, inManagedObjectContext: managedObjectContext) as! User
            postsVC = PostsPageViewController(thread: thread, author: user)
        } else {
            postsVC = PostsPageViewController(thread: thread)
        }
        
        try! managedObjectContext.save()
        
        var rawPage = AwfulThreadPage.None.rawValue
        let pageString = parameters["page"] as? String
        if
            let userID = userID where userID.isEmpty,
            let pageString = pageString
        {
            if pageString.caseInsensitiveCompare("last") == .OrderedSame {
                rawPage = AwfulThreadPage.Last.rawValue
            } else if pageString.caseInsensitiveCompare("unread") == .OrderedSame {
                rawPage = AwfulThreadPage.NextUnread.rawValue
            }
        }
        if rawPage == AwfulThreadPage.None.rawValue {
            if let pageNumber = pageString.flatMap({ Int($0) }) {
                rawPage = pageNumber
            } else if thread.beenSeen {
                rawPage = AwfulThreadPage.NextUnread.rawValue
            } else {
                rawPage = 1
            }
        }
        postsVC.loadPage(rawPage, updatingCache: true, updatingLastReadPost: true)
        
        if let postID = parameters["post"] as? String where !postID.isEmpty {
            let postKey = PostKey(postID: postID)
            let post = Post.objectForKey(postKey, inManagedObjectContext: managedObjectContext) as! Post
            postsVC.scrollPostToVisible(post)
        }
        
        return showPostsViewController(postsVC)
    }
    
    private func showPostsViewController(postsVC: PostsPageViewController) -> Bool {
        postsVC.restorationIdentifier = "Posts from URL"
        
        // Showing a posts view controller as a result of opening a URL is not the same as simply showing a detail view controller. We want to push it on to an existing navigation stack. Which one depends on how the split view is currently configured.
        let targetNav: UINavigationController
        guard let splitVC = rootViewController as? UISplitViewController else { return false }
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
    
    private func fetchUser(withUserID userID: String, completion: (NSError?, User?) -> Void) {
        let key = UserKey(userID: userID, username: nil)
        if let user = User.existingObjectForKey(key, inManagedObjectContext: managedObjectContext) as? User {
            completion(nil, user)
            return
        }
        
        AwfulForumsClient.sharedClient().profileUserWithID(userID, username: nil, andThen: { (error, profile) in
            completion(error, profile.user)
        })
    }
}
