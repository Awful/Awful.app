//  CopyURLActivity.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Adds a "Copy URL" activity. The target URL needs to go through wrapURL() before being added to the activityItems array, and no other activities will see or attempt to use the URL.
class CopyURLActivity: UIActivity {
    class func wrapURL(_ url: URL) -> AnyObject {
        return URLToCopyContainer(url)
    }
    
    override open var activityType: UIActivityType {
        get {
            return UIActivityType("com.awfulapp.Awful.CopyURL")
        }
    }
    
    override open class var activityCategory: UIActivityCategory {
        get {
            return .action
        }
    }
    
    override open var activityTitle: String? {
        get {
            return overriddenTitle ?? "Copy URL"
        }
    }
    
    fileprivate var overriddenTitle: String?
    
    /// Change the title from the default "Copy URL". Useful for distinguishing the target URL from other URLs that may be activity items.
    convenience init(title: String) {
        self.init()
        overriddenTitle = title
    }
    
    override open var activityImage: UIImage? {
        get {
            return UIImage(named: "copy")
        }
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return any(activityItems) { $0 is URLToCopyContainer }
    }
    
    fileprivate var url: URL!
    
    override func prepare(withActivityItems activityItems: [Any]) {
        let container = first(activityItems) { $0 is URLToCopyContainer } as! URLToCopyContainer
        url = container.url
    }
    
    override func perform() {
        UIPasteboard.general.awful_URL = url
    }
    
    /// Wraps an NSURL so that only the CopyURLActivity will try to use it.
    fileprivate class URLToCopyContainer: NSObject {
        let url: URL
        
        init(_ url: URL) {
            self.url = url
            super.init()
        }
    }
}
