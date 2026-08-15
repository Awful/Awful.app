//  ScreenshotHandlers+Awful.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulScreenshot
import MRProgress
import SwiftUI
import UIKit
import WebKit

extension ScreenshotHandlers {
    /// The app's implementation of what the screenshotter can't do itself: rendering posts through
    /// the posts-page machinery (Stencil template + custom URL schemes), the smilie picker, and the
    /// MRProgress overlays.
    @MainActor static var awful: ScreenshotHandlers {
        ScreenshotHandlers(
            renderPostsHTML: { posts, theme in
                var context: [String: Any] = [:]
                context["stylesheet"] = theme[string: "postsViewCSS"] as Any
                context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet
                context["posts"] = posts.map { PostRenderModel($0).context }

                if let forum = posts.first?.thread?.forum, !forum.forumID.isEmpty {
                    context["forumID"] = forum.forumID
                }
                if let thread = posts.first?.thread, !thread.threadID.isEmpty {
                    context["threadID"] = thread.threadID
                }
                context["tweetTheme"] = theme[string: "postsTweetTheme"] ?? "light"

                return try StencilEnvironment.shared.renderTemplate(.postsView, context: context)
            },
            makeWebViewConfiguration: {
                let config = WKWebViewConfiguration()
                config.setURLSchemeHandler(ImageURLProtocol(), forURLScheme: ImageURLProtocol.scheme)
                config.setURLSchemeHandler(ResourceURLProtocol(), forURLScheme: ResourceURLProtocol.scheme)
                return config
            },
            makeSmiliePicker: { didPick in
                AnyView(SmiliePickerView(dataStore: .shared) { smilie in
                    if let data = smilie.imageData, let image = UIImage(data: data) {
                        didPick(image)
                    } else {
                        didPick(nil)
                    }
                })
            },
            showProgressOverlay: { title in
                guard let window = keyWindow() else { return }
                MRProgressOverlayView.showOverlayAdded(to: window, title: title, mode: .indeterminate, animated: true)
            },
            dismissProgressOverlay: {
                guard let window = keyWindow() else { return }
                MRProgressOverlayView.dismissAllOverlays(for: window, animated: true)
            },
            showSavedOverlay: {
                guard let window = keyWindow() else { return }
                let overlay = MRProgressOverlayView.showOverlayAdded(to: window, title: "Saved", mode: .checkmark, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    overlay?.dismiss(true)
                }
            }
        )
    }

    @MainActor private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
