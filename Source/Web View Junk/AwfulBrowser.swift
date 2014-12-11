//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension SVWebViewController {
    class func presentBrowserForURL(URL: NSURL, fromViewController presentingViewController: UIViewController) -> SVWebViewController {
        let browser = SVWebViewController(URL: URL)
        browser.restorationIdentifier = "Awful Browser"
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad || presentingViewController.navigationController == nil {
            let navigation = browser.enclosingNavigationController
            let closeButton = UIBarButtonItem(title: "Close", style: .Plain, target: browser, action: "awful_close")
            browser.navigationItem.leftBarButtonItem = closeButton
            presentingViewController.presentViewController(navigation, animated: true, completion: nil)
        } else if let navigation = presentingViewController.navigationController {
            navigation.pushViewController(browser, animated: true)
        }
        return browser
    }
    
    @objc private func awful_close() {
        dismissViewControllerAnimated(true, completion: nil)
    }
}
