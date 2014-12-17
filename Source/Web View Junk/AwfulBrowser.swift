//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension YABrowserViewController {
    class func presentBrowserForURL(URL: NSURL, fromViewController presentingViewController: UIViewController) -> YABrowserViewController {
        let browser = YABrowserViewController()
        browser.URLString = URL.absoluteString
        browser.restorationIdentifier = "Awful Browser"
        browser.applicationActivities = [TUSafariActivity(), ARChromeActivity()]
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad || presentingViewController.navigationController == nil {
            browser.presentFromViewController(presentingViewController, animated: true, completion: nil)
        } else if let navigation = presentingViewController.navigationController {
            navigation.pushViewController(browser, animated: true)
        }
        return browser
    }
}
