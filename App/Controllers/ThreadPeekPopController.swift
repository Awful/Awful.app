//  ThreadPeekPopController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MRProgress
import UIKit

final class ThreadPeekPopController: NSObject, PreviewActionItemProvider, UIViewControllerPreviewingDelegate {
    private weak var previewingViewController: UIViewController?
    private var thread: Thread?
    
    init<ViewController: UIViewController where ViewController: ThreadPeekPopControllerDelegate>(previewingViewController: ViewController) {
        self.previewingViewController = previewingViewController
        
        super.init()
    }
    
    // MARK: PreviewActionItemProvider
    
    var previewActionItems: [UIPreviewActionItem] {
        let copyAction = UIPreviewAction(title: "Copy URL", style: .Default) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            let components = NSURLComponents(string: "http://forums.somethingawful.com/showthread.php")!
            var queryItems: [NSURLQueryItem] = []
            queryItems.append(NSURLQueryItem(name: "threadid", value: thread?.threadID))
            queryItems.append(NSURLQueryItem(name: "perpage", value: "40"))
            if (postsViewController.page > 1) {
                queryItems.append(NSURLQueryItem(name:"pagenumber", value: "\(postsViewController.page)"))
            }
            components.queryItems = queryItems
            
            let URL = components.URL!
            AwfulSettings.sharedSettings().lastOfferedPasteboardURL = URL.absoluteString
            UIPasteboard.generalPasteboard().awful_URL = URL
        }
        
        let markAsReadAction = UIPreviewAction(title: "Mark Thread As Read", style: .Default) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            AwfulForumsClient.sharedClient().listPostsInThread(thread, writtenBy: nil, onPage: .Last, updateLastReadPost: true, andThen: { (error, _, _, _) -> Void in
                guard let
                    error = error,
                    previewingViewController = postsViewController.parentViewController
                else {
                    return
                }
                
                let alert = UIAlertController(networkError: error, handler: nil)
                previewingViewController.presentViewController(alert, animated: true, completion: nil)
            })
        }
        
        let bookmarkTitle = thread?.bookmarked == true ? "Remove Bookmark" : "Add Bookmark"
        let bookmarkStyle: UIPreviewActionStyle = thread?.bookmarked == true ? .Destructive : .Default
        let bookmarkAction = UIPreviewAction(title: bookmarkTitle, style: bookmarkStyle) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            AwfulForumsClient.sharedClient().setThread(thread, isBookmarked:!thread.bookmarked) { error in
                guard let presentingViewController = previewViewController.parentViewController else {
                    return
                }
                
                if let error = error {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    presentingViewController.presentViewController(alert, animated: true, completion: nil)
                } else {
                    let title = thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAddedTo(presentingViewController.view, title: title, mode: .Checkmark, animated: true)
                    
                    NSTimer.scheduledTimerWithTimeInterval(0.7) { timer in
                        overlay.dismiss(true)
                    }
                }
            }
        }
        
        return [copyAction, markAsReadAction, bookmarkAction]
    }
    
    // MARK: UIViewControllerPreviewingDelegate
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let
            delegate = previewingViewController as? ThreadPeekPopControllerDelegate,
            thread = delegate.threadForLocation(location)
        else {
            return nil
        }
        
        self.thread = thread
        
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.NextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: false)
        
        postsViewController.preferredContentSize = CGSize(width: 0, height: 500)
        postsViewController.previewActionItemProvider = self
        
        if let view = delegate.viewForThread(thread) {
            previewingContext.sourceRect = view.frame
        }
        
        return postsViewController
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        guard let viewController = previewingViewController else {
            return
        }
        
        viewController.showViewController(viewControllerToCommit, sender: self)
    }
}

protocol ThreadPeekPopControllerDelegate {
    func threadForLocation(location: CGPoint) -> Thread?
    func viewForThread(thread: Thread) -> UIView?
}

@objc protocol PreviewActionItemProvider {
    var previewActionItems: [UIPreviewActionItem] { get }
}
