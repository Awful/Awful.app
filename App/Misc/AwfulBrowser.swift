//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SafariServices

final class AwfulBrowser: NSObject {
    @discardableResult class func presentBrowserForURL(
        _ url: URL,
        fromViewController presentingViewController: UIViewController)
        -> SFSafariViewController
    {
        let browser = SFSafariViewController(url: url)
        browser.delegate = sharedInstance
        browser.restorationIdentifier = "Awful Browser"
        presentingViewController.present(browser, animated: true)
        return browser
    }
    
    fileprivate static var sharedInstance = AwfulBrowser()
}

extension AwfulBrowser: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, activityItemsFor url: URL, title: String?) -> [UIActivity] {
        return [ChromeActivity(url: url)]
    }
}
