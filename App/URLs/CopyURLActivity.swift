//  CopyURLActivity.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Adds a "Copy URL" activity. The target URL needs to go through wrapURL() before being added to the activityItems array, and no other activities will see or attempt to use the URL.
class CopyURLActivity: UIActivity {
    class func wrapURL(URL: NSURL) -> AnyObject {
        return URLToCopyContainer(URL)
    }
    
    override class func activityType() -> UIActivityType {
        return UIActivityType("com.awfulapp.Awful.CopyURL")
    }
    
    override class func activityCategory() -> UIActivityCategory {
        return .action
    }
    
    override func activityTitle() -> String? {
        return overriddenTitle ?? "Copy URL"
    }
    
    private var overriddenTitle: String?
    
    /// Change the title from the default "Copy URL". Useful for distinguishing the target URL from other URLs that may be activity items.
    convenience init(title: String) {
        self.init()
        overriddenTitle = title
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: "copy")
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return any(sequence: activityItems) { $0 is URLToCopyContainer }
    }
    
    private var URL: NSURL!
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        let container = first(sequence: activityItems) { $0 is URLToCopyContainer } as! URLToCopyContainer
        URL = container.URL
    }
    
    override func perform() {
        UIPasteboard.general.awful_URL = URL
    }
    
    /// Wraps an NSURL so that only the CopyURLActivity will try to use it.
    private class URLToCopyContainer: NSObject {
        let URL: NSURL
        
        init(_ URL: NSURL) {
            self.URL = URL
            super.init()
        }
    }
}
