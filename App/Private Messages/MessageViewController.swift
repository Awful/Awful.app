//  MessageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import GRMustache
import WebViewJavascriptBridge

/// Displays a single private message.
final class MessageViewController: AwfulViewController {
    private let privateMessage: PrivateMessage
    private var didRender = false
    private var fractionalContentOffsetOnLoad: CGFloat = 0
    private var composeVC: MessageComposeViewController?
    private var webViewJavascriptBridge: WebViewJavascriptBridge?
    private var networkActivityIndicatorManager: WebViewNetworkActivityIndicatorManager?
    private var loadingView: LoadingView?
    private var didLoadOnce = false
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init(nibName: nil, bundle: nil)
        
        title = privateMessage.subject
        navigationItem.rightBarButtonItem = replyButtonItem
        hidesBottomBarWhenPushed = true
        restorationClass = self.dynamicType
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(settingsDidChange), name: AwfulSettingsDidChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var replyButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Reply, target: self, action: #selector(didTapReplyButtonItem))
    }()
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    private var webView: UIWebView {
        return view as! UIWebView
    }
    
    private func renderMessage() {
        let viewModel = PrivateMessageViewModel(privateMessage: privateMessage)
        viewModel.stylesheet = theme["postsViewCSS"]
        let html: String
        do {
            html = try GRMustacheTemplate.renderObject(viewModel, fromResource: "PrivateMessage", bundle: nil)
        } catch {
            print("\(#function) error rendering private message: \(error)")
            html = ""
        }
        webView.loadHTMLString(html, baseURL: AwfulForumsClient.sharedClient().baseURL)
        didRender = true
        
        webView.fractionalContentOffset = fractionalContentOffsetOnLoad
    }
    
    @objc private func didTapReplyButtonItem(sender: UIBarButtonItem?) {
        let actionSheet = UIAlertController.actionSheet()
        
        actionSheet.addActionWithTitle("Reply") {
            AwfulForumsClient.sharedClient().quoteBBcodeContentsOfPrivateMessage(self.privateMessage, andThen: { [weak self] (error, BBcode) in
                if let error = error {
                    self?.presentViewController(UIAlertController.alertWithTitle("Could Not Quote Message", error: error), animated: true, completion: nil)
                    return
                }
                
                guard let BBcode = BBcode else { fatalError("no error should mean yes BBcode") }
                guard let privateMessage = self?.privateMessage else { return }
                let composeVC = MessageComposeViewController(regardingMessage: privateMessage, initialContents: BBcode)
                composeVC.delegate = self
                composeVC.restorationIdentifier = "New private message replying to private message"
                self?.composeVC = composeVC
                self?.presentViewController(composeVC.enclosingNavigationController, animated: true, completion: nil)
            })
        }
        
        actionSheet.addActionWithTitle("Forward") { 
            AwfulForumsClient.sharedClient().quoteBBcodeContentsOfPrivateMessage(self.privateMessage, andThen: { [weak self] (error, BBcode) in
                if let error = error {
                    self?.presentViewController(UIAlertController.alertWithTitle("Could Not Quote Message", error: error), animated: true, completion: nil)
                    return
                }
                
                guard let BBcode = BBcode else { fatalError("no error should mean yes BBcode") }
                guard let privateMessage = self?.privateMessage else { return }
                let composeVC = MessageComposeViewController(forwardingMessage: privateMessage, initialContents: BBcode)
                composeVC.delegate = self
                composeVC.restorationIdentifier = "New private message forwarding private message"
                self?.composeVC = composeVC
                self?.presentViewController(composeVC.enclosingNavigationController, animated: true, completion: nil)
            })
        }
        
        actionSheet.addCancelActionWithHandler(nil)
        presentViewController(actionSheet, animated: true, completion: nil)
        
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    @objc private func didLongPressWebView(sender: UILongPressGestureRecognizer) {
        guard sender.state == .Began else { return }
        var location = sender.locationInView(webView)
        let offsetY = webView.scrollView.contentOffset.y
        if offsetY < 0 {
            location.y += offsetY
        }
        let data = ["x": location.x, "y": location.y]
        webViewJavascriptBridge?.callHandler("interestingElementsAtPoint", data: data) { [weak self] (response) in
            self?.webView.stringByEvaluatingJavaScriptFromString("Awful.preventNextClickEvent()")
            
            guard
                let response = response as? [String: AnyObject] where !response.isEmpty,
                let presenter = self
                else { return }
            
            let ok = URLMenuPresenter.presentInterestingElements(response, fromViewController: presenter, fromWebView: presenter.webView)
            if !ok && response["unspoiledLink"] == nil {
                print("\(#function) unexpected interesting elements for data: \(data), response: \(response)")
            }
        }
    }
    
    private func showUserActions(from rect: CGRect) {
        guard let user = privateMessage.from else { return }
        
        func present(viewController: UIViewController) {
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                self.presentViewController(viewController.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = [
            IconActionItem(.UserProfile, block: {
                present(ProfileViewController(user: user))
            }),
            IconActionItem(.RapSheet, block: {
                present(RapSheetViewController(user: user))
            })
        ]
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            guard let rectString = self.webView.stringByEvaluatingJavaScriptFromString("HeaderRect()") else { return }
            sourceRect.memory = self.webView.rectForElementBoundingRect(rectString)
            sourceView.memory = self.webView
        }
        presentViewController(actionVC, animated: true, completion: nil)
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard isViewLoaded() else { return }
        switch notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String {
        case AwfulSettingsKeys.showAvatars.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("showAvatars", data: AwfulSettings.sharedSettings().showAvatars)
            
        case AwfulSettingsKeys.showImages.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("loadLinkifiedImages")
            
        case AwfulSettingsKeys.fontScale.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("fontScale", data: Int(AwfulSettings.sharedSettings().fontScale))
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue()? where visible:
            configureUserActivity()
            
        default:
            break
        }
    }
    
    private func configureUserActivity() {
        guard AwfulSettings.sharedSettings().handoffEnabled else { return }
        userActivity = NSUserActivity(activityType: Handoff.ActivityTypeReadingMessage)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(activity: NSUserActivity) {
        activity.addUserInfoEntriesFromDictionary([Handoff.InfoMessageIDKey: privateMessage.messageID])
        if let subject = privateMessage.subject where !subject.isEmpty {
            activity.title = subject
        } else {
            activity.title = "Private Message"
        }
        activity.webpageURL = NSURL(string: "/private.php?action=show&privatemessageid=\(privateMessage.messageID)", relativeToURL: AwfulForumsClient.sharedClient().baseURL)
    }
    
    // MARK: View lifecycle
    
    override func loadView() {
        view = UIWebView.nativeFeelingWebView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        networkActivityIndicatorManager = WebViewNetworkActivityIndicatorManager(nextDelegate: self)
        
        webViewJavascriptBridge = WebViewJavascriptBridge(forWebView: webView, webViewDelegate: networkActivityIndicatorManager, handler: { (data, callback) in
            print("\(#function) \(data)")
        })
        webViewJavascriptBridge?.registerHandler("didTapUserHeader", handler: { [weak self] (rectString, responseCallback) in
            guard let
                rectString = rectString as? String,
                rect = self?.webView.rectForElementBoundingRect(rectString)
                else { return }
            self?.showUserActions(from: rect)
        })
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressWebView))
        longPress.delegate = self
        webView.addGestureRecognizer(longPress)
        
        if privateMessage.innerHTML == nil || privateMessage.innerHTML?.isEmpty == true || privateMessage.from == nil {
            let loadingView = LoadingView.loadingViewWithTheme(theme)
            self.loadingView = loadingView
            view.addSubview(loadingView)
            
            AwfulForumsClient.sharedClient().readPrivateMessageWithKey(privateMessage.objectKey, andThen: { [weak self] (error, message) in
                self?.title = message.subject
                
                self?.renderMessage()
                
                self?.loadingView?.removeFromSuperview()
                self?.loadingView = nil
                
                self?.userActivity?.needsSave = true
                
                if !message.seen {
                    NewMessageChecker.sharedChecker.decrementUnreadCount()
                    message.seen = true
                }
            })
        } else {
            renderMessage()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        if didRender, let css = theme["postsViewCSS"] as String? {
            webViewJavascriptBridge?.callHandler("changeStylesheet", data: css)
        }
        
        loadingView?.tintColor = theme["backgroundColor"]
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUserActivity()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(privateMessage.objectKey, forKey: Keys.MessageKey.rawValue)
        coder.encodeObject(composeVC, forKey: Keys.ComposeViewController.rawValue)
        coder.encodeFloat(Float(webView.fractionalContentOffset), forKey: Keys.ScrollFraction.rawValue)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        composeVC = coder.decodeObjectForKey(Keys.ComposeViewController.rawValue) as? MessageComposeViewController
        composeVC?.delegate = self
        
        fractionalContentOffsetOnLoad = CGFloat(coder.decodeFloatForKey(Keys.ScrollFraction.rawValue))
    }
}

extension MessageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismissViewControllerAnimated(true, completion: nil)
        
        composeVC = nil
    }
}

extension MessageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MessageViewController: UIViewControllerRestoration {
    static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        guard let messageKey = coder.decodeObjectForKey(Keys.MessageKey.rawValue) as? PrivateMessageKey else { return nil }
        let context = AppDelegate.instance.managedObjectContext
        guard let privateMessage = PrivateMessage.objectForKey(messageKey, inManagedObjectContext: context) as? PrivateMessage else { return nil }
        let messageVC = self.init(privateMessage: privateMessage)
        messageVC.restorationIdentifier = identifierComponents.last as? String
        return messageVC
    }
}

private enum Keys: String {
    case MessageKey
    case ComposeViewController = "AwfulComposeViewController"
    case ScrollFraction = "AwfulScrollFraction"
}

extension MessageViewController: UIWebViewDelegate {
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.URL else { return true }
        
        var navigationType = navigationType
        // Tapping the title of an embedded YouTube video doesn't come through as a click. It'll just take over the web view if we're not careful.
        if url.host?.lowercaseString.hasSuffix("www.youtube.com") == true && url.path?.lowercaseString.hasPrefix("/watch") == true {
            navigationType = .LinkClicked
        }
        
        guard navigationType == .LinkClicked else { return true }
        if let awfulURL = url.awfulURL {
            AppDelegate.instance.openAwfulURL(awfulURL)
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.sharedApplication().openURL(url)
        }
        return false
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        if !didLoadOnce {
            didLoadOnce = true
            
            webView.fractionalContentOffset = fractionalContentOffsetOnLoad
        }
        
        if AwfulSettings.sharedSettings().embedTweets {
            webViewJavascriptBridge?.callHandler("embedTweets")
        }
    }
}
