//  PostLocator.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSearch
import AwfulTheming
import CoreData
import MRProgress
import UIKit

/**
 Builds a `PostsPageViewController` showing a particular post, hitting the network to locate the
 post's page when it isn't already cached.

 Deliberately does *not* place the resulting view controller, and deliberately doesn't impose any
 failure UI: callers disagree on both. `AwfulURLRouter` pushes onto a split-view-dependent
 navigation stack behind a "Locating Post" overlay, while `RapSheetViewController` uses
 `showDetailViewController` with no overlay and an alert on failure.
 */
/// Isolation mirrors the call sites this was extracted from: the cached lookup is synchronous and
/// nonisolated (`AwfulURLRouter.route` is nonisolated and needs an answer before it returns), while
/// the networked variants stay on the main actor, as they did inside their original `Task { @MainActor in }`.
enum PostLocator {

    /// A posts page for an already-cached post, or nil when the post isn't in the store or its page
    /// isn't known yet (in which case the caller needs ``makePostsPageViewController(postID:updateLastReadPost:)``).
    ///
    /// Synchronous so callers can keep answering "did I handle this?" without waiting on the network.
    static func cachedPostsPageViewController(
        postID: String,
        updateLastReadPost: Bool,
        in context: NSManagedObjectContext
    ) -> PostsPageViewController? {
        let key = PostKey(postID: postID)
        guard let post = Post.existingObjectForKey(objectKey: key, in: context),
              let thread = post.thread,
              post.page > 0
        else { return nil }

        let postsVC = PostsPageViewController(thread: thread)
        postsVC.loadPage(.specific(post.page), updatingCache: true, updatingLastReadPost: updateLastReadPost)
        postsVC.scrollPostToVisible(post)
        return postsVC
    }

    /// Asks the forums which page the post is on, then builds a posts page scrolled to it.
    ///
    /// Note this uses the page the forums report rather than the post's cached `page`, which may be
    /// stale or unset.
    @MainActor
    static func makePostsPageViewController(
        postID: String,
        updateLastReadPost: Bool
    ) async throws -> PostsPageViewController {
        let (post, page) = try await ForumsClient.shared.locatePost(
            id: postID, updateLastReadPost: updateLastReadPost)
        guard let thread = post.thread else {
            throw MissingThread()
        }

        let postsVC = PostsPageViewController(thread: thread)
        postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: updateLastReadPost)
        postsVC.scrollPostToVisible(post)
        return postsVC
    }

    /// The located post turned out to have no thread, so there's nowhere to show it.
    struct MissingThread: Error {}

    /// Runs `work` behind a "Locating Post" overlay, leaving a failure message up briefly if it throws.
    ///
    /// - Returns: what `work` returned, once the overlay has finished dismissing, or nil if it threw.
    ///   Waiting for the dismissal keeps callers from pushing a view controller out from behind the
    ///   overlay while it's still animating away.
    @MainActor
    static func withLocatingOverlay<T>(
        in host: UIView,
        title: String = "Locating Post",
        failureTitle: String = "Post Not Found",
        _ work: () async throws -> T
    ) async -> T? {
        guard let overlay = MRProgressOverlayView.showOverlayAdded(
            to: host, title: title, mode: .indeterminate, animated: true)
        else { return try? await work() }
        overlay.tintColor = Theme.defaultTheme()["tintColor"]

        do {
            let result = try await work()
            await overlay.dismissAnimated()
            return result
        } catch {
            overlay.titleLabelText = failureTitle
            overlay.mode = .cross
            try? await Task.sleep(timeInterval: 3)
            overlay.dismiss(true)
            return nil
        }
    }
}

extension SearchHandlers {
    /// The app's implementation of what the search screens can't do themselves. Opening a post uses
    /// `showDetailViewController` rather than a push: on iPad the posts page belongs in the detail
    /// column, and when collapsed the split view pushes onto the results' stack anyway.
    @MainActor static var awful: SearchHandlers {
        SearchHandlers(openPost: { postID, from in
            let postsVC = await PostLocator.withLocatingOverlay(in: from.view) {
                try await PostLocator.makePostsPageViewController(
                    postID: postID, updateLastReadPost: false)
            }
            guard let postsVC else { return }
            from.showDetailViewController(postsVC, sender: from)
        })
    }
}

private extension MRProgressOverlayView {
    /// `dismiss(_:completion:)`, but suspends until the dismissal animation finishes.
    func dismissAnimated() async {
        await withCheckedContinuation { continuation in
            dismiss(true) { continuation.resume() }
        }
    }
}
