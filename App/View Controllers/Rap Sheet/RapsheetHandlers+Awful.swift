//  RapsheetHandlers+Awful.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulRapsheet
import AwfulTheming
import UIKit
import WebKit

extension RapsheetHandlers {
    /// The app's implementation of what the rap sheet can't do itself: rendering through the
    /// posts-page machinery (`RenderView` + the Leper's Colony Stencil template), refresh
    /// bookkeeping, serving the probation icon, and navigation.
    static var awful: RapsheetHandlers {
        RapsheetHandlers(
            makeRenderer: { LepersColonyRenderView() },
            renderTemplate: { context in
                (try? StencilEnvironment.shared.renderTemplate(.lepersColony, context: context)) ?? ""
            },
            makeLoadingView: { theme in
                LoadingView.loadingViewWithTheme(theme)
            },
            shouldRefreshLepersColony: { RefreshMinder.sharedMinder.shouldRefresh(.lepersColony) },
            didRefreshLepersColony: { RefreshMinder.sharedMinder.didRefresh(.lepersColony) },
            probationIconURL: {
                // The path must start with "/" — `awful-image://` URLs have an empty authority, so a
                // relative path would make `URLComponents.url` nil (and `ImageURLProtocol` force-unwraps it).
                guard let image = UIImage(named: "title-probation"),
                      let url = ImageURLProtocol.serveImage(image, atPath: "/leper-probation")
                else { return "" }
                return url.absoluteString
            },
            openPost: { postID, from in
                // From the tab this shows in the split-view detail column (like tapping a thread in the
                // forums list) rather than pushing into the sidebar the way `open(route:)` does here; the
                // modal Rap Sheet dismisses and lets the router place the post.
                if from.presentingViewController != nil {
                    AppDelegate.instance.open(route: .post(id: postID, .noseen))
                    from.dismiss(animated: true)
                    return
                }

                // No loading overlay here: the detail's `PostsPageViewController` shows its own while it
                // loads, so the sidebar list shouldn't flash a refresh spinner just for opening a post.
                Task { @MainActor in
                    do {
                        let (post, page) = try await ForumsClient.shared.locatePost(id: postID, updateLastReadPost: false)
                        guard let thread = post.thread else { return }
                        let postsVC = PostsPageViewController(thread: thread)
                        postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: false)
                        postsVC.scrollPostToVisible(post)
                        from.showDetailViewController(postsVC, sender: from)
                    } catch {
                        from.present(UIAlertController(networkError: error), animated: true)
                    }
                }
            },
            handleLink: { url, from in
                if let route = try? AwfulRoute(url) {
                    AppDelegate.instance.open(route: route)
                } else if url.opensInBrowser {
                    URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: from)
                } else {
                    UIApplication.shared.open(url)
                }
            },
            makeSidebarImageButton: { image, accessibilityLabel, pointSize, target, action in
                // The rap sheet only asks for these on the iOS 26 iPad path.
                guard #available(iOS 26.0, *) else { return UIView() }
                return NavigationController.makeSidebarImageHostingView(
                    image: image,
                    accessibilityLabel: accessibilityLabel,
                    pointSize: pointSize,
                    target: target,
                    action: action
                )
            },
            makeSidebarMenuButton: { image, accessibilityLabel, pointSize, menu in
                // The rap sheet only asks for these on the iOS 26 iPad path.
                guard #available(iOS 26.0, *) else { return UIView() }
                return NavigationController.makeSidebarMenuButtonView(
                    image: image,
                    accessibilityLabel: accessibilityLabel,
                    pointSize: pointSize,
                    menu: menu
                )
            }
        )
    }
}

/// Adapts the app's `RenderView` to the package's `RapsheetRenderer` surface.
private final class LepersColonyRenderView: RapsheetRenderer {

    private let renderView: RenderView

    var view: UIView { renderView }
    var scrollView: UIScrollView { renderView.scrollView }

    var didTapPunishmentPost: ((String) -> Void)?
    var didTapLink: ((URL) -> Void)?
    var renderProcessDidTerminate: (() -> Void)?

    init() {
        // No frog/ghost animations here, so skip injecting the sizable lottie-player.js.
        renderView = RenderView(includesLottiePlayer: false)
        renderView.delegate = self
        renderView.registerMessage(DidTapPunishmentPost.self)
    }

    func render(html: String, baseURL: URL?) {
        renderView.render(html: html, baseURL: baseURL)
    }

    func append(html: String, containerID: String) async {
        await renderView.appendPostHTML(html, containerID: containerID)
    }

    func setThemeStylesheet(_ css: String) {
        renderView.setThemeStylesheet(css)
    }

    private struct DidTapPunishmentPost: RenderViewMessage {
        static let messageName = "didTapPunishmentPost"
        let postID: String?

        init?(rawMessage: WKScriptMessage, in renderView: RenderView) {
            assert(rawMessage.name == DidTapPunishmentPost.messageName)
            postID = (rawMessage.body as? [String: Any])?["postID"] as? String
        }
    }
}

extension LepersColonyRenderView: RenderViewDelegate {
    func didFinishRenderingHTML(in view: RenderView) {
        // nop
    }

    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case let message as DidTapPunishmentPost:
            guard let postID = message.postID else { return }
            didTapPunishmentPost?(postID)

        default:
            break
        }
    }

    func didTapLink(to url: URL, in view: RenderView) {
        didTapLink?(url)
    }

    func renderProcessDidTerminate(in view: RenderView) {
        renderProcessDidTerminate?()
    }
}

extension RapSheetViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        // Only the tab-root instance needs to advertise a route; user-specific rap sheets are pushed/presented on top of a parent that already conforms, so walking past them is correct.
        isLepersColony ? .lepersColony : nil
    }
}
