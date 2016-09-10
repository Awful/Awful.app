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
        presentingViewController.present(browser, animated: true, completion: nil)
        return browser
    }
    
    fileprivate static var sharedInstance = AwfulBrowser()
}

extension AwfulBrowser: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, activityItemsFor URL: URL, title: String?) -> [UIActivity] {
        return [ARChromeActivity()]
    }
}
