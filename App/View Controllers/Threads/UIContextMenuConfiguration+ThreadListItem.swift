//  ThreadPeekPopController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import MRProgress
import os
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadPeekPopController")

extension UIContextMenuConfiguration {
    static func makeFromThreadList(
        for thread: AwfulThread,
        presenter: UIViewController,
        theme: Theme? = nil
    ) -> UIContextMenuConfiguration {
        func jump(to page: ThreadPage) {
            let postsPage = PostsPageViewController(thread: thread)
            postsPage.restorationIdentifier = "Posts"
            postsPage.loadPage(page, updatingCache: true, updatingLastReadPost: true)
            presenter.showDetailViewController(postsPage, sender: self)
        }
        // Helper function to wrap action handlers
        func wrappedAction(title: String, image: UIImage?, attributes: UIMenuElement.Attributes = [], handler: @escaping () -> Void) -> UIAction {
            return UIAction(title: title, image: image, attributes: attributes) { _ in
                handler()
                // Theme restoration is handled by UIContextMenuInteractionDelegate
            }
        }
        
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggested in
            // Ensure windows match app theme before showing context menu
            ContextMenuThemeManager.shared.ensureWindowsMatchAppTheme()
            
            return UIMenu(children: [
                wrappedAction(
                    title: NSLocalizedString("Jump to First Page", comment: ""),
                    image: UIImage(named: "jump-to-first-page")?.withRenderingMode(.alwaysTemplate)
                ) { jump(to: .first) },
                
                wrappedAction(
                    title: NSLocalizedString("Last Page", comment: ""),
                    image: UIImage(named: "jump-to-last-page")?.withRenderingMode(.alwaysTemplate)
                ) { jump(to: .last) },
                
                thread.author.map { author in
                    wrappedAction(
                        title: NSLocalizedString("Author Profile", comment: ""),
                        image: UIImage(named: "user-profile")?.withRenderingMode(.alwaysTemplate)
                    ) {
                        let profile = ProfileViewController(user: author)
                        if presenter.traitCollection.userInterfaceIdiom == .pad {
                            presenter.present(profile.enclosingNavigationController, animated: true)
                        } else {
                            presenter.navigationController?.pushViewController(profile, animated: true)
                        }
                    }
                },
                
                wrappedAction(
                    title: NSLocalizedString("Copy URL", comment: ""),
                    image: UIImage(named: "copy-url")?.withRenderingMode(.alwaysTemplate)
                ) {
                    let url = AwfulRoute.threadPage(
                        threadID: thread.threadID,
                        page: .first,
                        .noseen
                    ).httpURL
                    @FoilDefaultStorageOptional(Settings.lastOfferedPasteboardURLString) var lastOfferedPasteboardURLString
                    lastOfferedPasteboardURLString = url.absoluteString
                    UIPasteboard.general.coercedURL = url
                },
                
                wrappedAction(
                    title: NSLocalizedString("Copy Title", comment: ""),
                    image: UIImage(named: "copy-title")?.withRenderingMode(.alwaysTemplate)
                ) {
                    UIPasteboard.general.string = thread.title
                },
                
                !thread.beenSeen ? wrappedAction(
                    title: NSLocalizedString("Mark Thread As Read", comment: ""),
                    image: UIImage(named: "mark-read-up-to-here")?.withRenderingMode(.alwaysTemplate)
                ) {
                    let threadInfo = thread.threadInfo
                    Task { [weak presenter] in
                        do {
                            _ = try await ForumsClient.shared.listPosts(
                                threadInfo: threadInfo,
                                authorUserID: nil,
                                page: .last,
                                updateLastReadPost: true
                            )
                        } catch {
                            logger.error("could not mark thread \(threadInfo.threadID) as read from table view context menu: \(error)")
                            if let presenter {
                                await MainActor.run {
                                    let alert = UIAlertController(networkError: error)
                                    presenter.present(alert, animated: true)
                                }
                            }
                        }
                    }
                } : nil,
                
                thread.beenSeen ? wrappedAction(
                    title: NSLocalizedString("Mark Unread", comment: ""),
                    image: UIImage(named: "mark-as-unread")?.withRenderingMode(.alwaysTemplate)
                ) {
                    let oldSeen = thread.seenPosts
                    let threadID = thread.threadID
                    thread.seenPosts = 0
                    Task { [weak presenter] in
                        do {
                            try await ForumsClient.shared.markUnread(threadID: threadID)
                        } catch {
                            await MainActor.run {
                                logger.error("could not mark thread \(threadID) unread from table view context menu: \(error)")
                                if thread.seenPosts == 0 {
                                    thread.seenPosts = oldSeen
                                }
                                if let presenter {
                                    let alert = UIAlertController(networkError: error)
                                    presenter.present(alert, animated: true)
                                }
                            }
                        }
                    }
                } : nil,
                
                wrappedAction(
                    title: "Set color",
                    image: UIImage(named: "rainbow")?.withRenderingMode(.alwaysTemplate)
                ) {
                    let profile = UIHostingController(rootView: BookmarkColorPicker(
                        setBookmarkColor: ForumsClient.shared.setBookmarkColor(threadID:category:),
                        thread: thread
                    ))
                    profile.modalPresentationStyle = .pageSheet
                    if let sheet = profile.sheetPresentationController {
                        sheet.detents = [.medium()]
                    }
                    presenter.present(profile, animated: true)
                },
                
                wrappedAction(
                    title: (thread.bookmarked
                            ? NSLocalizedString("Remove Bookmark", comment: "")
                            : NSLocalizedString("Add Bookmark", comment: "")),
                    image: UIImage(named: thread.bookmarked
                                   ? "remove-bookmark"
                                   : "add-bookmark")?.withRenderingMode(.alwaysTemplate),
                    attributes: thread.bookmarked ? .destructive : []
                ) {
                    let wasBookmarked = thread.bookmarked
                    let threadID = thread.threadID
                    Task { [weak presenter] in
                        do {
                            try await ForumsClient.shared.setThread(threadID: threadID, isBookmarked: !wasBookmarked)

                            // Something is weird here, as without this `MainActor.run` we end up on a background thread, but it seems redundant (and, indeed, explicitly annotating the nearest `Task` with `@MainActor` still leaves us on a background thread).
                            let overlay = await MainActor.run { () -> MRProgressOverlayView? in
                                guard let presenter else { return nil }
                                return MRProgressOverlayView.showOverlayAdded(
                                    to: presenter.view,
                                    title: (!wasBookmarked
                                            ? NSLocalizedString("Added Bookmark", comment: "")
                                            : NSLocalizedString("Removed Bookmark", comment: "")),
                                    mode: .checkmark,
                                    animated: true
                                )
                            }
                            try? await Task.sleep(timeInterval: 0.7)
                            await MainActor.run {
                                overlay?.dismiss(true)
                            }
                        } catch {
                            await MainActor.run {
                                logger.error("could not toggle bookmarked on thread \(threadID) from table view context menu: \(error)")
                                if let presenter {
                                    let alert = UIAlertController(networkError: error)
                                    presenter.present(alert, animated: true)
                                }
                            }
                        }
                    }
                },
            ].compactMap { $0 })
        })
        
        // Apply iOS 26 styling to the configuration
        if #available(iOS 16.0, *) {
            configuration.preferredMenuElementOrder = UIContextMenuConfiguration.ElementOrder.fixed
        }
        
        return configuration
    }
}
