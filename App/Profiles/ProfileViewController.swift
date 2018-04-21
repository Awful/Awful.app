//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import AwfulCore
import TUSafariActivity
import UIKit
import WebKit

private let Log = Logger.get()

/// Shows detailed information about a particular user.
final class ProfileViewController: ViewController {
    private var networkActivityIndicator: WebViewActivityIndicatorManager?

    private var user: User {
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        networkActivityIndicator = WebViewActivityIndicatorManager(webView: webView)
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
        ForumsClient.shared.profileUser(id: user.userID, username: user.username)
            .done { [weak self] profile in
                guard let sself = self else { return }
                sself.user = profile.user
                sself.renderProfile()
            }
            .catch { error in
                print("error fetching user profile for \(username ?? "") (ID \(userID)): \(error)")
        }
    }
    
    private func renderProfile() {
        let html: String
        if let profile = user.profile {
            let viewModel = ProfileViewModel(profile)
            do {
                html = try MustacheTemplate.render(.profile, value: viewModel)
            }
            catch {
                Log.e("could not render profile HTML: \(error)")
                html = ""
            }
        } else {
            html = ""
        }
        webView.loadHTMLString(html, baseURL: baseURL)
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
    
    private func sendPrivateMessage() {
        let composeViewController = MessageComposeViewController(recipient: user)
        present(composeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    private func showActionsForHomepage(_ url: URL, atRect rect: CGRect) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
        present(activityViewController, animated: true, completion: nil)
        let popover = activityViewController.popoverPresentationController
        popover?.sourceRect = rect
        popover?.sourceView = self.webView
    }
}
