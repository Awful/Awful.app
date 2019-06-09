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
                let page = itemType == .jumpToLastPage ? ThreadPage.last : .first
                postsViewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
                viewController.showDetailViewController(postsViewController, sender: self)
            }
        }
        items.append(jumpToPageItem(.jumpToFirstPage))
        items.append(jumpToPageItem(.jumpToLastPage))
        
        let bookmarkItemType: IconAction = thread.bookmarked ? .removeBookmark : .addBookmark
        items.append(IconActionItem(bookmarkItemType) { [weak viewController] in
            _ = ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
            .catch { (error) -> Void in
                let alert = UIAlertController(networkError: error)
                viewController?.present(alert, animated: true)
            }
            })
        
        if let author = thread.author {
            items.append(IconActionItem(.userProfile) {
                let profile = ProfileViewController(user: author)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    viewController.present(profile.enclosingNavigationController, animated: true)
                } else {
                    viewController.navigationController?.pushViewController(profile, animated: true)
                }
                })
        }
        
        items.append(IconActionItem(.copyURL) {
            if let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=\(thread.threadID)") {
                UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
                UIPasteboard.general.coercedURL = url
            }
            })
        
        items.append(IconActionItem(.copyTitle) {
            UIPasteboard.general.string = thread.title
        })
        
        if thread.beenSeen {
            items.append(IconActionItem(.markAsUnread) { [weak viewController] in
                let oldSeen = thread.seenPosts
                thread.seenPosts = 0
                _ = ForumsClient.shared.markUnread(thread)
                    .catch { (error) -> Void in
                        if thread.seenPosts == 0 {
                            thread.seenPosts = oldSeen
                        }
                        let alert = UIAlertController(networkError: error)
                        viewController?.present(alert, animated: true)
                }
            })
        }

        self.items = items
    }
}
