//  UIApplication+OpenURL.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIApplication {
    /**
     Attempts to open the resource at the specified URL.

     `open(_ url:options:completionHandler:)` is unavailable in UIKit for Mac but was only introduced in iOS 10, so this method bridges the gap.
     */
    func open(_ url: URL) {
        #if targetEnvironment(macCatalyst)
        open(url, options: [:])
        #else
        openURL(url)
        #endif
    }
}
