//  RapsheetHandlers.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

/// The web view that renders the punishment list. The app supplies its posts-page render view
/// (an app-only type this package can't import); the rap sheet drives it through this narrow
/// surface and hears back through the callbacks.
@MainActor
public protocol RapsheetRenderer: AnyObject {

    /// The view to install in the view hierarchy.
    var view: UIView { get }

    /// The web view's scroll view (for insets, pull-to-refresh, and the endless-scroll trigger).
    var scrollView: UIScrollView { get }

    /// Called when the user taps a punishment row that links to a post.
    var didTapPunishmentPost: ((_ postID: String) -> Void)? { get set }

    /// Called when the user taps a link in a punishment reason. Routing policy is the app's.
    var didTapLink: ((URL) -> Void)? { get set }

    /// Called when the web content process dies (and the view is likely blank). The rap sheet
    /// responds by re-rendering the whole document.
    var renderProcessDidTerminate: (() -> Void)? { get set }

    /// Replaces the document with a fresh render.
    func render(html: String, baseURL: URL?)

    /// Appends punishment rows to the element with the given ID (endless scroll).
    func append(html: String, containerID: String) async

    /// Swaps in a new theme stylesheet without re-rendering.
    func setThemeStylesheet(_ css: String)
}

/// What the app does on the rap sheet's behalf. The package stays out of everything that depends
/// on app-only machinery: the render view and its Stencil template, refresh bookkeeping, serving
/// the probation icon, and navigation (opening a punished post, routing tapped links).
public struct RapsheetHandlers {

    /// Makes the web view the punishment list renders into.
    public var makeRenderer: @MainActor () -> RapsheetRenderer

    /// Renders the Leper's Colony template with the given context. Called off the main actor for
    /// full-document renders, so the implementation must be safe to call from any thread.
    public var renderTemplate: (_ context: [String: Any]) -> String

    /// Makes the full-screen loading overlay shown during page loads.
    public var makeLoadingView: @MainActor (_ theme: Theme) -> UIView

    /// Whether the Leper's Colony tab has gone long enough without a refresh to warrant one.
    public var shouldRefreshLepersColony: () -> Bool

    /// Records that the Leper's Colony tab just refreshed.
    public var didRefreshLepersColony: () -> Void

    /// A URL string that serves the probation icon to the rendered document. (The ban icons are
    /// loose bundle resources the document can address directly; probation lives only in an asset
    /// catalog, so the app has to serve it specially.)
    public var probationIconURL: () -> String

    /// Opens the post a user was punished for. `from` is the rap sheet asking; the handler owns
    /// placement (detail column vs. modal dismissal and routing) and any failure UI.
    public var openPost: @MainActor (_ postID: String, _ from: UIViewController) -> Void

    /// Routes a link tapped in a punishment reason. `from` is the rap sheet asking, for any
    /// presentation the handler needs to do.
    public var handleLink: @MainActor (_ url: URL, _ from: UIViewController) -> Void

    /// Makes a navigation-bar icon button for the iOS 26 iPad glass sidebar, which mis-tints
    /// plain buttons. Mirrors the app's forums-tab buttons.
    public var makeSidebarImageButton: @MainActor (
        _ image: UIImage,
        _ accessibilityLabel: String,
        _ pointSize: CGFloat,
        _ target: AnyObject,
        _ action: Selector
    ) -> UIView

    public init(
        makeRenderer: @escaping @MainActor () -> RapsheetRenderer,
        renderTemplate: @escaping (_ context: [String: Any]) -> String,
        makeLoadingView: @escaping @MainActor (_ theme: Theme) -> UIView,
        shouldRefreshLepersColony: @escaping () -> Bool,
        didRefreshLepersColony: @escaping () -> Void,
        probationIconURL: @escaping () -> String,
        openPost: @escaping @MainActor (_ postID: String, _ from: UIViewController) -> Void,
        handleLink: @escaping @MainActor (_ url: URL, _ from: UIViewController) -> Void,
        makeSidebarImageButton: @escaping @MainActor (
            _ image: UIImage,
            _ accessibilityLabel: String,
            _ pointSize: CGFloat,
            _ target: AnyObject,
            _ action: Selector
        ) -> UIView
    ) {
        self.makeRenderer = makeRenderer
        self.renderTemplate = renderTemplate
        self.makeLoadingView = makeLoadingView
        self.shouldRefreshLepersColony = shouldRefreshLepersColony
        self.didRefreshLepersColony = didRefreshLepersColony
        self.probationIconURL = probationIconURL
        self.openPost = openPost
        self.handleLink = handleLink
        self.makeSidebarImageButton = makeSidebarImageButton
    }
}
