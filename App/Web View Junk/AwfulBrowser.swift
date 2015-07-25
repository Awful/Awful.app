//  AwfulBrowser.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import TUSafariActivity
import YABrowserViewController

extension YABrowserViewController {
    class func presentBrowserForURL(URL: NSURL, fromViewController presentingViewController: UIViewController) -> YABrowserViewController {
        let browser = YABrowserViewController()
        browser.URLString = URL.absoluteString
        browser.restorationIdentifier = "Awful Browser"
        browser.applicationActivities = [TUSafariActivity(), ARChromeActivity()]
        browser.presentFromViewController(presentingViewController, animated: true, completion: nil)
        return browser
    }
}
