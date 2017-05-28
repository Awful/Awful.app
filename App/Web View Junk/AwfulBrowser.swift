//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import SafariServices

final class AwfulBrowser: NSObject {
    @discardableResult class func presentBrowserForURL(_ URL: Foundation.URL, fromViewController presentingViewController: UIViewController) -> SFSafariViewController {
        let browser = SFSafariViewController(url: URL)
        browser.delegate = sharedInstance
        browser.restorationIdentifier = "Awful Browser"
        UIApplication.shared.keyWindow?.rootViewController?.present(browser, animated: true, completion: nil)
        return browser
    }
    
    fileprivate static var sharedInstance = AwfulBrowser()
}

extension AwfulBrowser: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, activityItemsFor url: URL, title: String?) -> [UIActivity] {
        return [Rdar24138390ChromeActivity(url: url)]
    }
}

/// Activity items in SFSafariViewController aren't sent `prepare(withActivityItems:)` for some unknown reason, so we work around that here.
private final class Rdar24138390ChromeActivity: ARChromeActivity {
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            guard let activityURL = item as? URL else { continue }
            return activityURL.absoluteURL == url.absoluteURL
        }
        
        return false
    }
    
    override func perform() {
        // `ARChromeActivity`, on advice from the documentation, uses `prepare(withActivityItems:)` to save the activity item being acted upon.
        prepare(withActivityItems: [url])
        
        super.perform()
    }
    
    override var activityImage: UIImage? {
        // Superclass checks in bundle for `self.class` instead of hardcoding `ARChromeActivity.self` so we need to unbreak that.
        return UIImage(named: "ARChromeActivity", in: Bundle(for: ARChromeActivity.self), compatibleWith: nil)
    }
}
