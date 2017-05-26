//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import ARChromeActivity
import AwfulCore
import GRMustache
import TUSafariActivity
import UIKit
import WebKit

/// Shows detailed information about a particular user.
final class ProfileViewController: ViewController {
    fileprivate var user: User {
        didSet { updateTitle() }
    }
    
    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
        
        updateTitle()
        modalPresentationStyle = .formSheet
        hidesBottomBarWhenPushed = true
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    var webView: WKWebView {
        return view as! WKWebView
    }
    
    fileprivate var networkActivityIndicator: NetworkActivityIndicatorForWKWebView!

    private func updateTitle() {
        title = user.username ?? "Profile"
    }
    
    override func loadView() {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "sendPrivateMessage")
        userContentController.add(self, name: "showHomepageActions")
        for filename in ["zepto.min.js", "common.js", "profile.js"] {
            let URL = Bundle.main.url(forResource: filename, withExtension: nil)
            var source : String = ""
            do {
                source = try NSString(contentsOf: URL!, encoding: String.Encoding.utf8.rawValue) as String
            }
            catch {
                NSException(name: NSExceptionName.internalInconsistencyException, reason: "could not load script at \(String(describing: URL))", userInfo: nil).raise()
            }
            let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(script)
        }
        configuration.userContentController = userContentController
        view = WKWebView(frame: CGRect.zero, configuration: configuration)
        networkActivityIndicator = NetworkActivityIndicatorForWKWebView(webView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        renderProfile()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        let darkMode = AwfulSettings.shared().darkTheme ? "true" : "false"
        webView.evaluateJavaScript("darkMode(\(darkMode))", completionHandler: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if presentingViewController != nil && navigationController?.viewControllers.count == 1 {
            let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
            doneItem.actionBlock = { _ in
                self.dismiss(animated: true, completion: nil)
            }
            navigationItem.leftBarButtonItem = doneItem
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        webView.scrollView.flashScrollIndicators()
        
        let (userID, username) = (user.userID, user.username)
        _ = ForumsClient.shared.profileUser(id: user.userID, username: user.username)
            .then { [weak self] (profile) -> Void in
                guard let sself = self else { return }
                sself.user = profile.user
                sself.renderProfile()
            }
            .catch { (error) in
                print("error fetching user profile for \(username ?? "") (ID \(userID)): \(error)")
        }
    }
    
    fileprivate func renderProfile() {
        var HTML = ""
        if let profile = user.profile {
            let viewModel = ProfileViewModel(profile: profile)
            do {
                HTML = try GRMustacheTemplate.renderObject(viewModel, fromResource: "Profile", bundle: nil)
            }
            catch {
                NSLog("[\(Mirror(reflecting:self)) \(#function)] error rendering user profile for \(String(describing: user.username)) (ID \(user.userID)): \(error)")
            }
        }
        webView.loadHTMLString(HTML, baseURL: baseURL)
    }
    
    var baseURL: URL? {
        return ForumsClient.shared.baseURL
    }
}

extension ProfileViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch (message.name) {
        case "sendPrivateMessage":
            sendPrivateMessage()
        case "showHomepageActions":
            let body = message.body as! [String:String]
            if
                let baseURL = baseURL,
                let urlString = body["URL"],
                let url = URL(string: urlString, relativeTo: baseURL)
            {
                showActionsForHomepage(url, atRect: CGRectFromString(body["rect"]!))
            }
        default:
            print("\(self) received unknown message from webview: \(message.name)")
        }
    }
    
    fileprivate func sendPrivateMessage() {
        let composeViewController = MessageComposeViewController(recipient: user)
        present(composeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    fileprivate func showActionsForHomepage(_ url: URL, atRect rect: CGRect) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
        present(activityViewController, animated: true, completion: nil)
        let popover = activityViewController.popoverPresentationController
        popover?.sourceRect = rect
        popover?.sourceView = self.webView
    }
}

// MARK: -

/**
The network activity indicator will show in the status bar while *any* NetworkActivityIndicatorForWKWebView is on.

NetworkActivityIndicatorForWKWebView will turn off during deinitialization.
*/
private class NetworkActivityIndicatorForWKWebView: NSObject {
    fileprivate(set) var on: Bool = false {
        didSet {
            if on && !oldValue {
                AFNetworkActivityIndicatorManager.shared().incrementActivityCount()
            } else if !on && oldValue {
                AFNetworkActivityIndicatorManager.shared().decrementActivityCount()
            }
        }
    }
    
    let webView: WKWebView
    
    init(_ webView: WKWebView) {
        self.webView = webView
        super.init()
        
        webView.addObserver(self, forKeyPath: "loading", options: .new, context: &KVOContext)
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: "loading", context: &KVOContext)
        on = false
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &KVOContext {
            if let loading = change![NSKeyValueChangeKey.newKey] as? NSNumber {
                on = loading.boolValue
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change , context: context)
        }
    }
}

private var KVOContext = 0
