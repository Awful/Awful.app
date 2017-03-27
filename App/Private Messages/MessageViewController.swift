//  MessageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import GRMustache
import WebViewJavascriptBridge

/// Displays a single private message.
final class MessageViewController: ViewController {
    fileprivate let privateMessage: PrivateMessage
    fileprivate var didRender = false
    fileprivate var fractionalContentOffsetOnLoad: CGFloat = 0
    fileprivate var composeVC: MessageComposeViewController?
    fileprivate var webViewJavascriptBridge: WebViewJavascriptBridge?
    fileprivate var networkActivityIndicatorManager: WebViewNetworkActivityIndicatorManager?
    fileprivate var loadingView: LoadingView?
    fileprivate var didLoadOnce = false
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init(nibName: nil, bundle: nil)
        
        title = privateMessage.subject
        navigationItem.rightBarButtonItem = replyButtonItem
        hidesBottomBarWhenPushed = true
        restorationClass = type(of: self)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate lazy var replyButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .reply, target: self, action: #selector(didTapReplyButtonItem))
    }()
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    fileprivate var webView: UIWebView {
        return view as! UIWebView
    }
    
    fileprivate func renderMessage() {
        let viewModel = PrivateMessageViewModel(privateMessage: privateMessage)
        viewModel.stylesheet = theme["postsViewCSS"] as String? as NSString?
        let html: String
        do {
            html = try GRMustacheTemplate.renderObject(viewModel, fromResource: "PrivateMessage", bundle: nil)
        } catch {
            print("\(#function) error rendering private message: \(error)")
            html = ""
        }
        webView.loadHTMLString(html, baseURL: AwfulForumsClient.shared().baseURL)
        didRender = true
        
        self.webViewJavascriptBridge?.callHandler("jumpToFractionalOffset", data: fractionalContentOffsetOnLoad)
    }
    
    @objc fileprivate func didTapReplyButtonItem(_ sender: UIBarButtonItem?) {
        let actionSheet = UIAlertController.actionSheet()
        
        actionSheet.addActionWithTitle("Reply") {
            _ = AwfulForumsClient.shared().quoteBBcodeContents(of: self.privateMessage, andThen: { [weak self] (error: Error?, BBcode: String?) in
                if let error = error {
                    self?.present(UIAlertController.alertWithTitle("Could Not Quote Message", error: error), animated: true, completion: nil)
                    return
                }
                
                guard let BBcode = BBcode else { fatalError("no error should mean yes BBcode") }
                guard let privateMessage = self?.privateMessage else { return }
                let composeVC = MessageComposeViewController(regardingMessage: privateMessage, initialContents: BBcode)
                composeVC.delegate = self
                composeVC.restorationIdentifier = "New private message replying to private message"
                self?.composeVC = composeVC
                self?.present(composeVC.enclosingNavigationController, animated: true, completion: nil)
            })
        }
        
        actionSheet.addActionWithTitle("Forward") {
            _ = AwfulForumsClient.shared().quoteBBcodeContents(of: self.privateMessage, andThen: { [weak self] (error: Error?, BBcode: String?) in
                if let error = error {
                    self?.present(UIAlertController.alertWithTitle("Could Not Quote Message", error: error), animated: true, completion: nil)
                    return
                }
                
                guard let BBcode = BBcode else { fatalError("no error should mean yes BBcode") }
                guard let privateMessage = self?.privateMessage else { return }
                let composeVC = MessageComposeViewController(forwardingMessage: privateMessage, initialContents: BBcode)
                composeVC.delegate = self
                composeVC.restorationIdentifier = "New private message forwarding private message"
                self?.composeVC = composeVC
                self?.present(composeVC.enclosingNavigationController, animated: true, completion: nil)
            })
        }
        
        actionSheet.addCancelActionWithHandler(nil)
        present(actionSheet, animated: true, completion: nil)
        
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    @objc fileprivate func didLongPressWebView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        var location = sender.location(in: webView)
        let offsetY = webView.scrollView.contentOffset.y
        if offsetY < 0 {
            location.y += offsetY
        }
        let data = ["x": location.x, "y": location.y]
        webViewJavascriptBridge?.callHandler("interestingElementsAtPoint", data: data) { [weak self] (response) in
            _ = self?.webView.stringByEvaluatingJavaScript(from: "Awful.preventNextClickEvent()")
            
            guard
                let response = response as? [String: AnyObject] , !response.isEmpty,
                let presenter = self
                else { return }
            
            let ok = URLMenuPresenter.presentInterestingElements(response, fromViewController: presenter, fromWebView: presenter.webView)
            if !ok && response["unspoiledLink"] == nil {
                print("\(#function) unexpected interesting elements for data: \(data), response: \(response)")
            }
        }
    }
    
    fileprivate func showUserActions(from rect: CGRect) {
        guard let user = privateMessage.from else { return }
        
        func present(_ viewController: UIViewController) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.present(viewController.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = [
            IconActionItem(.userProfile, block: {
                present(ProfileViewController(user: user))
            }),
            IconActionItem(.rapSheet, block: {
                present(RapSheetViewController(user: user))
            })
        ]
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            guard let rectString = self.webView.stringByEvaluatingJavaScript(from: "HeaderRect()") else { return }
            sourceRect.pointee = self.webView.rectForElementBoundingRect(rectString)
            sourceView.pointee = self.webView
        }
        self.present(actionVC, animated: true, completion: nil)
    }
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        guard isViewLoaded else { return }
        switch notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String as NSString? {
        case AwfulSettingsKeys.showAvatars.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("showAvatars", data: AwfulSettings.shared().showAvatars)
            
        case AwfulSettingsKeys.showImages.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("loadLinkifiedImages")
            
        case AwfulSettingsKeys.fontScale.takeUnretainedValue()?:
            webViewJavascriptBridge?.callHandler("fontScale", data: Int(AwfulSettings.shared().fontScale))
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue()? where visible:
            configureUserActivity()
            
        default:
            break
        }
    }
    
    fileprivate func configureUserActivity() {
        guard AwfulSettings.shared().handoffEnabled else { return }
        userActivity = NSUserActivity(activityType: Handoff.ActivityTypeReadingMessage)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.addUserInfoEntries(from: [Handoff.InfoMessageIDKey: privateMessage.messageID])
        if let subject = privateMessage.subject , !subject.isEmpty {
            activity.title = subject
        } else {
            activity.title = "Private Message"
        }
        activity.webpageURL = URL(string: "/private.php?action=show&privatemessageid=\(privateMessage.messageID)", relativeTo: AwfulForumsClient.shared().baseURL)
    }
    
    // MARK: View lifecycle
    
    override func loadView() {
        view = UIWebView.nativeFeelingWebView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        networkActivityIndicatorManager = WebViewNetworkActivityIndicatorManager(nextDelegate: self)
        
        webViewJavascriptBridge = WebViewJavascriptBridge(for: webView, webViewDelegate: networkActivityIndicatorManager, handler: { (data, callback) in
            print("\(#function) \(String(describing: data))")
        })
        webViewJavascriptBridge?.registerHandler("didTapUserHeader", handler: { [weak self] (rectString, responseCallback) in
            guard let
                rectString = rectString as? String,
                let rect = self?.webView.rectForElementBoundingRect(rectString)
                else { return }
            self?.showUserActions(from: rect)
        })
        
        webViewJavascriptBridge?.registerHandler("didFinishLoadingTweets", handler: { [weak self] (data, callback) in
           if let fraction = self?.fractionalContentOffsetOnLoad, fraction > 0 {
                self?.webViewJavascriptBridge?.callHandler("jumpToFractionalOffset", data: fraction)
            }
        })
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressWebView))
        longPress.delegate = self
        webView.addGestureRecognizer(longPress)
        
        if privateMessage.innerHTML == nil || privateMessage.innerHTML?.isEmpty == true || privateMessage.from == nil {
            let loadingView = LoadingView.loadingViewWithTheme(theme)
            self.loadingView = loadingView
            view.addSubview(loadingView)
            
            AwfulForumsClient.shared().readPrivateMessage(with: privateMessage.objectKey, andThen: { [weak self] (error: Error?, message: PrivateMessage?) in
                self?.title = message?.subject
                
                self?.renderMessage()
                
                self?.loadingView?.removeFromSuperview()
                self?.loadingView = nil
                
                self?.userActivity?.needsSave = true
                
                if message?.seen == false {
                    NewMessageChecker.sharedChecker.decrementUnreadCount()
                    message?.seen = true
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUserActivity()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(privateMessage.objectKey, forKey: Keys.MessageKey.rawValue)
        coder.encode(composeVC, forKey: Keys.ComposeViewController.rawValue)
        coder.encode(Float(webView.fractionalContentOffset), forKey: Keys.ScrollFraction.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        composeVC = coder.decodeObject(forKey: Keys.ComposeViewController.rawValue) as? MessageComposeViewController
        composeVC?.delegate = self
        
        fractionalContentOffsetOnLoad = CGFloat(coder.decodeFloat(forKey: Keys.ScrollFraction.rawValue))
    }
}

extension MessageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
        
        composeVC = nil
    }
}

extension MessageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MessageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        guard let messageKey = coder.decodeObject(forKey: Keys.MessageKey.rawValue) as? PrivateMessageKey else { return nil }
        let context = AppDelegate.instance.managedObjectContext
        guard let privateMessage = PrivateMessage.objectForKey(objectKey: messageKey, inManagedObjectContext: context) as? PrivateMessage else { return nil }
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

/// Twitter and YouTube embeds try to use taps to take over the frame. Here we try to detect that and treat it as if a link was tapped.
fileprivate func isHijackingWebView(_ navigationType: UIWebViewNavigationType, url: URL) -> Bool {
    guard case .other = navigationType else { return false }
    guard let host = url.host?.lowercased() else { return false }
    if host.hasSuffix("www.youtube.com") && url.path.lowercased().hasPrefix("/watch") {
        return true
    } else if
        host.hasSuffix("twitter.com"),
        let thirdComponent = url.pathComponents.dropFirst(2).first,
        thirdComponent.lowercased() == "status"
    {
        return true
    } else {
        return false
    }
}

extension MessageViewController: UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.url else { return true }
        guard navigationType == .linkClicked || isHijackingWebView(navigationType, url: url) else { return true }
        
        var navigationType = navigationType
        // Tapping the title of an embedded YouTube video doesn't come through as a click. It'll just take over the web view if we're not careful.
        if url.host?.lowercased().hasSuffix("www.youtube.com") == true && url.path.lowercased().hasPrefix("/watch") == true {
            navigationType = .linkClicked
        }
        
        guard navigationType == .linkClicked || url.host?.lowercased().hasSuffix("twitter.com") == true else { return true }
        if let awfulURL = url.awfulURL {
            AppDelegate.instance.openAwfulURL(awfulURL)
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.openURL(url)
        }
        return false
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if !didLoadOnce {
            didLoadOnce = true
            
            self.webViewJavascriptBridge?.callHandler("jumpToFractionalOffset", data: fractionalContentOffsetOnLoad)
        }
        
        if AwfulSettings.shared().embedTweets {
            webViewJavascriptBridge?.callHandler("embedTweets")
        }
    }
}
