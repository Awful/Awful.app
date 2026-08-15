//  ScreenshotHandlers.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import SwiftUI
import UIKit
import WebKit

/// What the app does on the screenshotter's behalf. The package stays out of the app's posts
/// rendering machinery (Stencil templates, custom URL scheme handlers), its smilie picker, and its
/// progress-overlay style, so all of those stay with the caller.
public struct ScreenshotHandlers {

    /// Renders the posts-view HTML for the given posts, styled with the given theme.
    public var renderPostsHTML: @MainActor (_ posts: [Post], _ theme: Theme) throws -> String

    /// A web view configuration able to serve the images and resources the posts-view HTML asks for.
    public var makeWebViewConfiguration: @MainActor () -> WKWebViewConfiguration

    /// A smilie picker. Calls `didPick` once with the chosen smilie's image, or `nil` if the
    /// choice couldn't be turned into an image; the picker is dismissed either way.
    public var makeSmiliePicker: @MainActor (_ didPick: @escaping (UIImage?) -> Void) -> AnyView

    /// Shows a modal progress overlay with the given (already localized) title.
    public var showProgressOverlay: @MainActor (_ title: String) -> Void

    /// Dismisses the overlay shown by `showProgressOverlay`.
    public var dismissProgressOverlay: @MainActor () -> Void

    /// Briefly confirms that sharing the screenshot completed.
    public var showSavedOverlay: @MainActor () -> Void

    public init(
        renderPostsHTML: @escaping @MainActor (_ posts: [Post], _ theme: Theme) throws -> String,
        makeWebViewConfiguration: @escaping @MainActor () -> WKWebViewConfiguration,
        makeSmiliePicker: @escaping @MainActor (_ didPick: @escaping (UIImage?) -> Void) -> AnyView,
        showProgressOverlay: @escaping @MainActor (_ title: String) -> Void,
        dismissProgressOverlay: @escaping @MainActor () -> Void,
        showSavedOverlay: @escaping @MainActor () -> Void
    ) {
        self.renderPostsHTML = renderPostsHTML
        self.makeWebViewConfiguration = makeWebViewConfiguration
        self.makeSmiliePicker = makeSmiliePicker
        self.showProgressOverlay = showProgressOverlay
        self.dismissProgressOverlay = dismissProgressOverlay
        self.showSavedOverlay = showSavedOverlay
    }
}
