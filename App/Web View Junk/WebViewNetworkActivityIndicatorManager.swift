//  WebViewNetworkActivityIndicatorManager.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking.AFNetworkActivityIndicatorManager
import UIKit

/// Taps into a UIWebViewDelegate so it works with an AFNetworkActivityIndicatorManager.
final class WebViewNetworkActivityIndicatorManager: NSObject {
    private let manager: AFNetworkActivityIndicatorManager
    private let nextDelegate: UIWebViewDelegate?
    private var activeRequestCount = 0 {
        didSet {
            if oldValue == 0 && activeRequestCount > 0 {
                manager.incrementActivityCount()
            } else if oldValue > 0 && activeRequestCount == 0 {
                manager.decrementActivityCount()
            }
        }
    }
    
    init(manager: AFNetworkActivityIndicatorManager, nextDelegate: UIWebViewDelegate?) {
        self.manager = manager
        self.nextDelegate = nextDelegate
        super.init()
    }
    
    /// Uses the shared AFNetworkActivityIndicatorManager.
    convenience init(nextDelegate: UIWebViewDelegate) {
        self.init(manager: AFNetworkActivityIndicatorManager.sharedManager(), nextDelegate: nextDelegate)
    }
    
    /// Uses the shared AFNetworkActivityIndicatorManager. and doesn't forward to a next delegate.
    convenience override init() {
        self.init(manager: AFNetworkActivityIndicatorManager.sharedManager(), nextDelegate: nil)
    }
    
    deinit {
        if activeRequestCount > 0 {
            manager.decrementActivityCount()
        }
    }
}

extension WebViewNetworkActivityIndicatorManager: UIWebViewDelegate {
    func webViewDidStartLoad(webView: UIWebView) {
        activeRequestCount += 1
        
        nextDelegate?.webViewDidStartLoad?(webView)
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        activeRequestCount -= 1
        
        nextDelegate?.webViewDidFinishLoad?(webView)
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        activeRequestCount -= 1
        
        nextDelegate?.webView?(webView, didFailLoadWithError: error)
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        return nextDelegate?.webView?(webView, shouldStartLoadWithRequest: request, navigationType: navigationType) ?? true
    }
}
