//  InAppActionViewController+ThreadActions.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

extension InAppActionViewController {
    convenience init(thread: AwfulThread, presentingViewController viewController: UIViewController) {
        self.init()
        
        var items = [IconActionItem]()
        
        func jumpToPageItem(_ itemType: IconAction) -> IconActionItem {
            return IconActionItem(itemType) {
                let postsViewController = PostsPageViewController(thread: thread)
                postsViewController.restorationIdentifier = "Posts"
                let page = itemType == .jumpToLastPage ? AwfulThreadPage.last.rawValue : 1
                postsViewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
                viewController.showDetailViewController(postsViewController, sender: self)
            }
        }
        items.append(jumpToPageItem(.jumpToFirstPage))
        items.append(jumpToPageItem(.jumpToLastPage))
        
        let bookmarkItemType: IconAction = thread.bookmarked ? .removeBookmark : .addBookmark
        items.append(IconActionItem(bookmarkItemType) { [weak viewController] in
            _ = ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked) { (error: Error?) in
                if let error = error {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    viewController?.present(alert, animated: true, completion: nil)
                }
            }
            return // hooray for implicit return
            })
        
        if let author = thread.author {
            items.append(IconActionItem(.userProfile) {
                let profile = ProfileViewController(user: author)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    viewController.present(profile.enclosingNavigationController, animated: true, completion: nil)
                } else {
                    viewController.navigationController?.pushViewController(profile, animated: true)
                }
                })
        }
        
        items.append(IconActionItem(.copyURL) {
            if let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=\(thread.threadID)") {
                AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                UIPasteboard.general.awful_URL = url
            }
            })
        
        if thread.beenSeen {
            items.append(IconActionItem(.markAsUnread) { [weak viewController] in
                let oldSeen = thread.seenPosts
                thread.seenPosts = 0
                _ = ForumsClient.shared.markUnread(thread) { (error: Error?) in
                    if let error = error {
                        if thread.seenPosts == 0 {
                            thread.seenPosts = oldSeen
                        }
                        let alert = UIAlertController(networkError: error, handler: nil)
                        viewController?.present(alert, animated: true, completion: nil)
                    }
                }
                })
        }
        
        self.items = items
    }
}
