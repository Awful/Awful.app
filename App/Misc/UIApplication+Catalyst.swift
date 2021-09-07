//  UIApplication+Catalyst.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIApplication {
    /**
     Attempts to open the resource at the specified URL.

     Calls `open(_:options:completionHandler:)` on iOS 10+ and Catalyst, falling back to `openURL(_:)` on iOS 9.
     */
    func open(_ url: URL, completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(iOS 10, *) {
            open(url, completionHandler: completion)
        } else {
            let result = openURL(url)
            completion(result)
        }
    }
}
