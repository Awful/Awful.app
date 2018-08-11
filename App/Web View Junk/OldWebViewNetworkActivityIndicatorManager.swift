//  OldWebViewNetworkActivityIndicatorManager.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Taps into a UIWebViewDelegate so it works with NetworkActivityIndicatorManager.
final class OldWebViewNetworkActivityIndicatorManager: NSObject {
    private let manager: NetworkActivityIndicatorManager
    private weak var nextDelegate: UIWebViewDelegate?

    private var activityCount = 0 {
        didSet {
            if oldValue == 0, activityCount > 0 {
                manager.incrementActivityCount()
            } else if oldValue > 0, activityCount == 0 {
                manager.decrementActivityCount()
            }
        }
    }
    
    init(manager: NetworkActivityIndicatorManager = .shared, nextDelegate: UIWebViewDelegate? = nil) {
        self.manager = manager
        self.nextDelegate = nextDelegate
    }
    
    deinit {
        // In case we disappear without the UIWebView telling us about everything finishing.
        if activityCount > 0 {
            manager.decrementActivityCount()
        }
    }
}

extension OldWebViewNetworkActivityIndicatorManager: UIWebViewDelegate {
    func webViewDidStartLoad(_ webView: UIWebView) {
        activityCount += 1
        
        nextDelegate?.webViewDidStartLoad?(webView)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        activityCount -= 1
        
        nextDelegate?.webViewDidFinishLoad?(webView)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        activityCount -= 1
        
        nextDelegate?.webView?(webView, didFailLoadWithError: error)
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        return nextDelegate?.webView?(webView, shouldStartLoadWith: request, navigationType: navigationType) ?? true
    }
}
