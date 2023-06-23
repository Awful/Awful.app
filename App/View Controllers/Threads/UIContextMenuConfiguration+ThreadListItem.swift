//  ThreadPeekPopController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress
import SwiftUI
import UIKit

private let Log = Logger.get()

extension UIContextMenuConfiguration {
    static func makeFromThreadList(
        for thread: AwfulThread,
        presenter: UIViewController
    ) -> UIContextMenuConfiguration {
        var copyTitle: UIMenuElement {
            UIAction(
                title: NSLocalizedString("Copy Title", comment: ""),
                image: UIImage(named: "copy-title")!.withRenderingMode(.alwaysTemplate),
                handler: { action in UIPasteboard.general.string = thread.title }
            )
        }
        var copyURL: UIMenuElement {
            UIAction(
                title: NSLocalizedString("Copy URL", comment: ""),
                image: UIImage(named: "copy-url")!.withRenderingMode(.alwaysTemplate),
                handler: { action in
                    let url = AwfulRoute.threadPage(
                        threadID: thread.threadID,
                        page: .first,
                        .noseen
                    ).httpURL
                    UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
                    UIPasteboard.general.coercedURL = url
                }
            )
        }
        func jump(to page: ThreadPage) {
            let postsPage = PostsPageViewController(thread: thread)
            postsPage.restorationIdentifier = "Posts"
            postsPage.loadPage(page, updatingCache: true, updatingLastReadPost: true)
            presenter.showDetailViewController(postsPage, sender: self)
        }
        var jumpToFirstPage: UIMenuElement {
            UIAction(
                title: NSLocalizedString("Jump to First Page", comment: ""),
                image: UIImage(named: "jump-to-first-page")!.withRenderingMode(.alwaysTemplate),
                handler: { action in jump(to: .first) }
            )
        }
        var setBookmarkColor: UIMenuElement {
            UIAction(
                title: "Set color",
                image: UIImage(named: "rainbow")!.withRenderingMode(.alwaysTemplate),
                attributes: [],
                handler: { action in
                    let profile = UIHostingController(rootView: BookmarkColorPicker(
                        setBookmarkColor: ForumsClient.shared.setBookmarkColor(_:as:),
                        thread: thread
                    ))
                    presenter.present(profile, animated: true)
                }
            )
        }
        var jumpToLastPage: UIMenuElement {
            UIAction(
                title: NSLocalizedString("Last Page", comment: ""),
                image: UIImage(named: "jump-to-last-page")!.withRenderingMode(.alwaysTemplate),
                handler: { action in jump(to: .last) }
            )
        }
        var markThreadRead: UIMenuElement? {
            guard !thread.beenSeen else { return nil }
            return UIAction(
                title: NSLocalizedString("Mark Thread As Read", comment: ""),
                image: UIImage(named: "mark-read-up-to-here")!.withRenderingMode(.alwaysTemplate),
                handler: { action in
                    _ = ForumsClient.shared.listPosts(
                        in: thread,
                        writtenBy: nil,
                        page: .last,
                        updateLastReadPost: true
                    ).promise
                        .catch { error in
                            Log.e("could not mark thread \(thread.threadID) as read from table view context menu: \(error)")
                            let alert = UIAlertController(networkError: error)
                            presenter.present(alert, animated: true)
                        }
                }
            )
        }
        var markThreadUnread: UIMenuElement? {
            guard thread.beenSeen else { return nil }
            return UIAction(
                title: NSLocalizedString("Mark Unread", comment: ""),
                image: UIImage(named: "mark-as-unread")!.withRenderingMode(.alwaysTemplate),
                handler: { action in
                    let oldSeen = thread.seenPosts
                    thread.seenPosts = 0
                    _ = ForumsClient.shared.markUnread(thread)
                        .catch { error in
                            Log.e("could not mark thread \(thread.threadID) unread from table view context menu: \(error)")
                            if thread.seenPosts == 0 {
                                thread.seenPosts = oldSeen
                            }
                            let alert = UIAlertController(networkError: error)
                            presenter.present(alert, animated: true)
                    }
                }
            )
        }
        var profileAuthor: UIMenuElement? {
            guard let author = thread.author else { return nil }
            return UIAction(
                title: NSLocalizedString("Author Profile", comment: ""),
                image: UIImage(named: "user-profile")!.withRenderingMode(.alwaysTemplate),
                handler: { action in
                    let profile = ProfileViewController(user: author)
                    if presenter.traitCollection.userInterfaceIdiom == .pad {
                        presenter.present(profile.enclosingNavigationController, animated: true)
                    } else {
                        presenter.navigationController?.pushViewController(profile, animated: true)
                    }
                }
            )
        }
        var toggleBookmark: UIMenuElement {
            UIAction(
                title: (thread.bookmarked
                        ? NSLocalizedString("Remove Bookmark", comment: "")
                        : NSLocalizedString("Add Bookmark", comment: "")),
                image: UIImage(named: thread.bookmarked
                               ? "remove-bookmark"
                               : "add-bookmark")!.withRenderingMode(.alwaysTemplate),
                attributes: thread.bookmarked ? .destructive : [],
                handler: { action in
                    _ = ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
                        .done {
                            let overlay = MRProgressOverlayView.showOverlayAdded(
                                to: presenter.view,
                                title: (thread.bookmarked
                                        ? NSLocalizedString("Added Bookmark", comment: "")
                                        : NSLocalizedString("Removed Bookmark", comment: "")),
                                mode: .checkmark,
                                animated: true
                            )

                            Timer.scheduledTimerWithInterval(0.7) { timer in
                                overlay?.dismiss(true)
                            }
                        }
                        .catch { error in
                            Log.e("could not toggle bookmarked on thread \(thread.threadID) from table view context menu: \(error)")
                            let alert = UIAlertController(networkError: error)
                            presenter.present(alert, animated: true)
                    }
                }
            )
        }
        return .init(identifier: nil, previewProvider: nil, actionProvider: { suggested in
            UIMenu(children: [
                jumpToFirstPage,
                jumpToLastPage,
                profileAuthor,
                copyURL,
                copyTitle,
                markThreadRead,
                markThreadUnread,
                setBookmarkColor,
                toggleBookmark,
            ].compactMap { $0 })
        })
    }
}
