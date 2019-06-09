//  WebViewNetworkActivityIndicatorManager.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import WebKit

/// Connects a `WKWebView` to a `NetworkActivityIndicatorManager`.
final class WebViewActivityIndicatorManager {
    private let indicatorManager: NetworkActivityIndicatorManager
    private var observation: NSKeyValueObservation?

    private(set) var on = false {
        didSet {
            if on, !oldValue {
                indicatorManager.incrementActivityCount()
            } else if !on, oldValue {
                indicatorManager.decrementActivityCount()
            }
        }
    }

    init(webView: WKWebView, activityIndicatorManager: NetworkActivityIndicatorManager = .shared) {
        indicatorManager = activityIndicatorManager

        observation = webView.observe(\.isLoading, options: [.initial, .new]) {
            // This `self` capture was originally `unowned` but that was very occasionally crashing trying to read an unowned reference to an instance that was already deallocated. This feels vaguely wrong (is someone doing a delayed-perform to notify KVO observers?), but the crash log was pretty convincing.
            [weak self] webView, change in
            
            guard let self = self, let newValue = change.newValue else { return }
            self.on = newValue
        }
    }

    deinit {
        if on {
            indicatorManager.decrementActivityCount()
        }
    }
}
