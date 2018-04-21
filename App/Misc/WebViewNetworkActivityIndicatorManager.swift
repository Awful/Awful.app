//
//  WebViewNetworkActivityIndicatorManager.swift
//  Awful
//
//  Created by Nolan Waite on 2018-04-21.
//  Copyright © 2018 Awful Contributors. All rights reserved.
//

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

        observation = webView.observe(\.isLoading, options: [.initial, .new]) { [unowned self] webView, change in
            self.on = change.newValue!
        }
    }

    deinit {
        if on {
            indicatorManager.decrementActivityCount()
        }
    }
}
