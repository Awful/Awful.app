//  InAppActionViewController+ThreadActions.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

extension InAppActionViewController {
    convenience init(thread: AwfulThread, presentingViewController viewController: UIViewController) {
        self.init()
        
        var items = [IconActionItem]()
        
        func jumpToPageItem(itemType: IconAction) -> IconActionItem {
            return IconActionItem(itemType) {
                let postsViewController = PostsPageViewController(thread: thread)
                postsViewController.restorationIdentifier = "Posts"
                let page = itemType == .JumpToLastPage ? AwfulThreadPage.last.rawValue : 1
                postsViewController.loadPage(rawPage: page, updatingCache: true, updatingLastReadPost: true)
                viewController.showDetailViewController(postsViewController, sender: self)
            }
        }
        items.append(jumpToPageItem(itemType: .JumpToFirstPage))
        items.append(jumpToPageItem(itemType: .JumpToLastPage))
        
        let bookmarkItemType: IconAction = thread.bookmarked ? .RemoveBookmark : .AddBookmark
        items.append(IconActionItem(bookmarkItemType) { [weak viewController] in
            AwfulForumsClient.shared().setThread(thread, isBookmarked: !thread.bookmarked) { (error: NSError?) in
                if let error = error {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    viewController?.presentViewController(alert, animated: true, completion: nil)
                }
            }
            return // hooray for implicit return
            })
        
        if let author = thread.author {
            items.append(IconActionItem(.UserProfile) {
                let profile = ProfileViewController(user: author)
                if UIDevice.currentDevice.userInterfaceIdiom == .Pad {
                    viewController.present(profile.enclosingNavigationController, animated: true, completion: nil)
                } else {
                    viewController.navigationController?.pushViewController(profile, animated: true)
                }
                })
        }
        
        items.append(IconActionItem(.CopyURL) {
            if let URL = NSURL(string: "https://forums.somethingawful.com/showthread.php?threadid=\(thread.threadID)") {
                AwfulSettings.shared().lastOfferedPasteboardURL = URL.absoluteString
                UIPasteboard.generalPasteboard.awful_URL = URL
            }
            })
        
        if thread.beenSeen {
            items.append(IconActionItem(.MarkAsUnread) { [weak viewController] in
                let oldSeen = thread.seenPosts
                thread.seenPosts = 0
                AwfulForumsClient.shared().markThreadUnread(thread) { (error: NSError?) in
                    if let error = error {
                        if thread.seenPosts == 0 {
                            thread.seenPosts = oldSeen
                        }
                        let alert = UIAlertController(networkError: error, handler: nil)
                        viewController?.presentViewController(alert, animated: true, completion: nil)
                    }
                }
                })
        }
        
        self.items = items
    }
}
