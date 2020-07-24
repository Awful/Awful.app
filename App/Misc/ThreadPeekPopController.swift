//  ThreadPeekPopController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress
import UIKit

#if !targetEnvironment(macCatalyst)

final class ThreadPeekPopController: NSObject, PreviewActionItemProvider, UIViewControllerPreviewingDelegate {

    private weak var previewingViewController: (UIViewController & ThreadPeekPopControllerDelegate)?
    private var thread: AwfulThread?
    
    init(previewingViewController: UIViewController & ThreadPeekPopControllerDelegate) {
        self.previewingViewController = previewingViewController
        
        super.init()
        
        previewingViewController.registerForPreviewing(with: self, sourceView: previewingViewController.view)
    }
    
    // MARK: PreviewActionItemProvider
    
    var previewActionItems: [UIPreviewActionItem] {
        let copyAction = UIPreviewAction(title: "Copy URL", style: .default) { action, previewViewController -> Void in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            let route = AwfulRoute.threadPage(threadID: thread.threadID, page: postsViewController.page ?? .first, .noseen)
            let url = route.httpURL
            UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
            UIPasteboard.general.coercedURL = url
        }
        
        let copyTitleAction = UIPreviewAction(title: "Copy Title", style: .default) { action, previewViewController -> Void in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            UIPasteboard.general.string = thread.title
        }
        
        let markAsReadAction = UIPreviewAction(title: "Mark Thread As Read", style: .default) { action, previewViewController -> Void in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread

            _ = ForumsClient.shared.listPosts(in: thread, writtenBy: nil, page: .last, updateLastReadPost: true)
                .promise
                .catch { error -> Void in
                    guard let previewingViewController = postsViewController.parent else {
                        return
                    }

                    let alert = UIAlertController(networkError: error)
                    previewingViewController.present(alert, animated: true)
            }
        }
        
        let bookmarkTitle = thread?.bookmarked == true ? "Remove Bookmark" : "Add Bookmark"
        let bookmarkStyle: UIPreviewAction.Style = thread?.bookmarked == true ? .destructive : .default
        let bookmarkAction = UIPreviewAction(title: bookmarkTitle, style: bookmarkStyle) { action, previewViewController -> Void in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            _ = ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
                .done {
                    guard let presentingViewController = previewViewController.parent else {
                        return
                    }

                    let title = thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAdded(to: presentingViewController.view, title: title, mode: .checkmark, animated: true)

                    Timer.scheduledTimerWithInterval(0.7) { timer in
                        overlay?.dismiss(true)
                    }
                }
                .catch { error in
                    guard let presentingViewController = previewViewController.parent else {
                        return
                    }

                    let alert = UIAlertController(networkError: error)
                    presentingViewController.present(alert, animated: true, completion: nil)
            }
        }
        
        return [copyAction, copyTitleAction, markAsReadAction, bookmarkAction]
    }
    
    // MARK: UIViewControllerPreviewingDelegate
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let thread = previewingViewController?.threadForLocation(location: location) else {
            return nil
        }
        
        self.thread = thread
        
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: false)
        
        postsViewController.preferredContentSize = CGSize(width: 0, height: 500)
        postsViewController.previewActionItemProvider = self
        
        if let view = previewingViewController?.viewForThread(thread: thread) {
            previewingContext.sourceRect = view.frame
        }
        
        return postsViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        guard let viewController = previewingViewController else {
            return
        }
        
        if let postsViewController = viewControllerToCommit as? PostsPageViewController, let page = postsViewController.page {
            postsViewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
            postsViewController.previewActionItemProvider = nil
        }
        
        viewController.show(viewControllerToCommit, sender: self)
    }
}

protocol ThreadPeekPopControllerDelegate {
    func threadForLocation(location: CGPoint) -> AwfulThread?
    func viewForThread(thread: AwfulThread) -> UIView?
}

protocol PreviewActionItemProvider: class {
    var previewActionItems: [UIPreviewActionItem] { get }
}

#endif
