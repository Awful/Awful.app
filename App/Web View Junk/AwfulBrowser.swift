//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import SafariServices

final class AwfulBrowser: NSObject {
    class func presentBrowserForURL(URL: NSURL, fromViewController presentingViewController: UIViewController) -> SFSafariViewController {
        let browser = SFSafariViewController(URL: URL)
        browser.delegate = sharedInstance
        browser.restorationIdentifier = "Awful Browser"
        presentingViewController.presentViewController(browser, animated: true, completion: nil)
        return browser
    }
    
    private static var sharedInstance = AwfulBrowser()
}

extension AwfulBrowser: SFSafariViewControllerDelegate {
    func safariViewController(controller: SFSafariViewController, activityItemsForURL URL: NSURL, title: String?) -> [UIActivity] {
        return [ARChromeActivity()]
    }
}
