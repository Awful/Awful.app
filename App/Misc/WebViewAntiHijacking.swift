//  WebViewAntiHijacking.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app


import WebKit

extension WKNavigationAction {

    /**
     Whether the navigation appears to be an embed trying to navigate away.

     Some embeds (Twitter, YouTube) try to navigate somewhere when the user taps a thing, and for whatever reason it doesn't get counted as a click event.
     */
    var isAttemptingToHijackWebView: Bool {
        guard case .other = navigationType else { return false }

        // TODO: worth considering `targetFrame` and/or `isMainFrame`?

        guard let url = request.url, let host = url.host?.lowercased() else { return false }
        if host.hasSuffix("www.youtube.com"), url.path.lowercased().hasPrefix("/watch") {
            return true
        }
        else if
            host.hasSuffix("twitter.com"),
            let thirdComponent = url.pathComponents.dropFirst(2).first,
            thirdComponent.lowercased() == "status"
        {
            return true
        }
        else {
            return false
        }
    }
}
