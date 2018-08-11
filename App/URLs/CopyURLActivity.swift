//  CopyURLActivity.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Adds a "Copy URL" activity. Place the target URL in a `Box` before adding it to `activityItems` and no other activities will see or attempt to use the URL.
final class CopyURLActivity: UIActivity {

    private let overriddenTitle: String?

    /// - Parameter title: Overrides the default "Copy URL" title.
    init(title: String? = nil) {
        overriddenTitle = title
    }

    /// Wraps a URL so that only the `CopyURLActivity` will try to use it.
    final class Box {
        fileprivate let url: URL

        init(_ url: URL) {
            self.url = url
        }
    }

    // MARK: UIActivity
    
    override var activityType: UIActivity.ActivityType {
        return UIActivity.ActivityType("com.awfulapp.Awful.CopyURL")
    }
    
    override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    override var activityTitle: String? {
        return overriddenTitle ?? LocalizedString("copy-url.title")
    }
    
    override var activityImage: UIImage? {
        return UIImage(named: "copy")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.any { $0 is Box }
    }
    
    fileprivate var url: URL!
    
    override func prepare(withActivityItems activityItems: [Any]) {
        url = activityItems.lazy.compactMap({ $0 as? Box }).first?.url
    }
    
    override func perform() {
        UIPasteboard.general.coercedURL = url
    }
}
