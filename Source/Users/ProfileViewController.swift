//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import WebKit

/// A ProfileViewController shows detailed information about a particular user.
class ProfileViewController: AwfulViewController {
    let user: AwfulUser
    private var webView: WKWebView { get { return view as WKWebView } }
    private let networkActivityIndicator = OnOffNetworkActivityIndicator()
    
    init(user: AwfulUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
        
        title = user.username ?? "Profile"
        modalPresentationStyle = .FormSheet
        hidesBottomBarWhenPushed = true
        navigationItem.backBarButtonItem = UIBarButtonItem.awful_emptyBackBarButtonItem()
    }
    
    override func loadView() {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.addScriptMessageHandler(self, name: "sendPrivateMessage")
        userContentController.addScriptMessageHandler(self, name: "showHomepageActions")
        for filename in ["zepto.min.js", "common.js", "profile.js"] {
            let URL = NSBundle.mainBundle().URLForResource(filename, withExtension: nil)
            var error: NSError?
            let source = NSString.stringWithContentsOfURL(URL!, encoding: NSUTF8StringEncoding, error: &error)
            if source == nil {
                NSException(name: NSInternalInconsistencyException, reason: "could not load script at \(URL)", userInfo: nil).raise()
            }
            let script = WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(script)
        }
        configuration.userContentController = userContentController
        view = WKWebView(frame: CGRectZero, configuration: configuration)
        webView.navigationDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderUser()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["backgroundColor"] as? UIColor
        webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        
        let darkMode = AwfulSettings.sharedSettings().darkTheme ? "true" : "false"
        webView.evaluateJavaScript("darkMode(\(darkMode))", completionHandler: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if presentingViewController != nil && self.navigationController?.viewControllers.count == 1 {
            let barButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: nil, action: nil)
            barButtonItem.awful_actionBlock = { (_) in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            navigationItem.leftBarButtonItem = barButtonItem
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        webView.scrollView.flashScrollIndicators()
        
        AwfulForumsClient.sharedClient().profileUserWithID(user.userID, username: user.username) { [unowned self] (error, user) in
            if let error = error {
                NSLog("[%@ %@] error fetching user profile for %@ (ID %@): %@", reflect(self).summary, __FUNCTION__, user.username, user.userID, error)
            } else {
                self.renderUser()
            }
        }
    }
    
    private func renderUser() {
        let viewModel = AwfulProfileViewModel(user: user)
        var error: NSError?
        let HTML = GRMustacheTemplate.renderObject(viewModel, fromResource: "Profile", bundle: nil, error: &error)
        if let error = error {
            NSLog("[%@ %@] error rendering profile for %@ (ID %@): %@", reflect(self).summary, __FUNCTION__, user.username, user.userID, error)
        }
        webView.loadHTMLString(HTML, baseURL: baseURL())
    }
    
    // MARK: Initializers not to be called
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}

private func baseURL() -> NSURL {
    return AwfulForumsClient.sharedClient().baseURL
}

extension ProfileViewController: WKNavigationDelegate {
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation) {
        networkActivityIndicator.on = true
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation) {
        networkActivityIndicator.on = false
    }
}

extension ProfileViewController: WKScriptMessageHandler {
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        switch (message.name) {
        case "sendPrivateMessage":
            sendPrivateMessage()
        case "showHomepageActions":
            let body = message.body as [String:String]
            let URL = NSURL(string: body["URL"]!, relativeToURL: baseURL())
            showActionsForHomepage(URL, atRect: CGRectFromString(body["rect"]))
        default:
            println("\(self) received unknown message from webview: \(message.name)")
        }
    }
    
    private func sendPrivateMessage() {
        let composeViewController = MessageComposeViewController(recipient: user)
        presentViewController(composeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    private func showActionsForHomepage(URL: NSURL, atRect rect: CGRect) {
        let activityViewController = UIActivityViewController(activityItems: [URL], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
        presentViewController(activityViewController, animated: true, completion: nil)
        let popover = activityViewController.popoverPresentationController
        popover?.sourceRect = rect
        popover?.sourceView = self.webView
    }
}

// MARK: -

/**
The network activity indicator will show in the status bar while *any* OnOffNetworkActivityIndicator is on.

OnOffNetworkActivityIndicator will turn off during deinitialization.
*/
private class OnOffNetworkActivityIndicator {
    var on: Bool = false {
        didSet {
            if on && !oldValue {
                AFNetworkActivityIndicatorManager.sharedManager().incrementActivityCount()
            } else if !on && oldValue {
                AFNetworkActivityIndicatorManager.sharedManager().decrementActivityCount()
            }
        }
    }
    
    deinit {
        on = false
    }
}
