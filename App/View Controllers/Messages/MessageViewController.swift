//  MessageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import HTMLReader

private let Log = Logger.get()

/// Displays a single private message.
final class MessageViewController: ViewController {
    
    @FoilDefaultStorage(Settings.autoplayGIFs) private var autoplayGIFs
    private var cancellables: Set<AnyCancellable> = []
    private var composeVC: MessageComposeViewController?
    private var didLoadOnce = false
    private var didRender = false
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    private var fractionalContentOffsetOnLoad: CGFloat = 0
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var loadingView: LoadingView?
    private let privateMessage: PrivateMessage
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages

    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()
    
    private lazy var replyButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(named: "reply"), style: .plain, target: self, action: #selector(didTapReplyButtonItem))
    }()
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init(nibName: nil, bundle: nil)
        
        title = privateMessage.subject
        
        navigationItem.rightBarButtonItem = replyButtonItem
        hidesBottomBarWhenPushed = true
        
        restorationClass = type(of: self)
    }
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    private func renderMessage() {
        do {
            let model = RenderModel(message: privateMessage, stylesheet: theme["postsViewCSS"])
            let rendering = try StencilEnvironment.shared.renderTemplate(.privateMessage, context: model)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            Log.e("failed to render private message: \(error)")
            
            // TODO: show error nicer
            renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
        }
        didRender = true
    }
    
    // MARK: Actions
    
    @objc private func didTapReplyButtonItem(_ sender: UIBarButtonItem) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        var actions: [UIAlertAction] = []
        actions.append(.default(title: LocalizedString("private-message.action-reply")) { [self] in
            Task {
                do {
                    let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: privateMessage)
                    let composeVC = MessageComposeViewController(regardingMessage: privateMessage, initialContents: bbcode)
                    composeVC.delegate = self
                    composeVC.restorationIdentifier = "New private message replying to private message"
                    self.composeVC = composeVC
                    present(composeVC.enclosingNavigationController, animated: true, completion: nil)
                } catch {
                    present(UIAlertController(title: LocalizedString("private-message.quote-error.title"), error: error), animated: true)
                }
            }
        })
        actions.append(.default(title: LocalizedString("private-message.action-forward")) { [self] in
            Task {
                do {
                    let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: privateMessage)
                    let composeVC = MessageComposeViewController(forwardingMessage: privateMessage, initialContents: bbcode)
                    composeVC.delegate = self
                    composeVC.restorationIdentifier = "New private message forwarding private message"
                    self.composeVC = composeVC
                    present(composeVC.enclosingNavigationController, animated: true)
                } catch {
                    present(UIAlertController(title: LocalizedString("private-message.quote-error.title"), error: error), animated: true)
                }
            }
        })
        actions.append(.cancel())
        
        let actionSheet = UIAlertController(actionSheetActions: actions)
        present(actionSheet, animated: true)
        
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    @objc private func didLongPressWebView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }

        Task {
            let elements = await renderView.interestingElements(at: sender.location(in: renderView))
            _ = URLMenuPresenter.presentInterestingElements(elements, from: self, renderView: self.renderView)
        }
    }
    
    private func showUserActions(from rect: CGRect) {
        guard let user = privateMessage.from else { return }
        
        func present(_ viewController: UIViewController) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.present(viewController.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        Task {
            var rect = await renderView.unionFrameOfElements(matchingSelector: ".avatar, .nameanddate")
            let actionVC = InAppActionViewController()
            actionVC.items = [
                IconActionItem(.userProfile, block: {
                    present(ProfileViewController(user: user))
                }),
                IconActionItem(.rapSheet, block: {
                    present(RapSheetViewController(user: user))
                })
            ]

            if rect.isNull {
                rect = CGRect(origin: .zero, size: CGSize(width: renderView.bounds.width, height: 1))
            }

            actionVC.popoverPositioningBlock = { sourceRect, sourceView in
                sourceRect.pointee = rect
                sourceView.pointee = self.renderView
            }

            self.present(actionVC, animated: true)
        }
    }
    
    // MARK: Handoff
    
    private func configureUserActivity() {
        guard handoffEnabled else { return }
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.readingMessage)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .message(id: privateMessage.messageID)
        activity.title = {
            if let subject = privateMessage.subject, !subject.isEmpty {
                return subject
            } else {
                return LocalizedString("handoff.message-title")
            }
        }()

        Log.d("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(renderView, at: 0)
        
        renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressWebView))
        longPress.delegate = self
        renderView.addGestureRecognizer(longPress)
        
        $embedTweets
            .dropFirst()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderView.embedTweets() }
            .store(in: &cancellables)

        $fontScale
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.renderView.setFontScale(Double($0)) }
            .store(in: &cancellables)

        $handoffEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if visible {
                    configureUserActivity()
                }
            }
            .store(in: &cancellables)

        $showAvatars
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.renderView.setShowAvatars($0) }
            .store(in: &cancellables)

        $showImages
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderView.loadLinkifiedImages() }
            .store(in: &cancellables)

        if privateMessage.innerHTML == nil || privateMessage.innerHTML?.isEmpty == true || privateMessage.from == nil {
            let loadingView = LoadingView.loadingViewWithTheme(theme)
            self.loadingView = loadingView
            view.addSubview(loadingView)

            Task {
                do {
                    let message = try await ForumsClient.shared.readPrivateMessage(identifiedBy: privateMessage.objectKey)
                    title = message.subject

                    if message.seen == false {
                        message.seen = true
                        try await message.managedObjectContext?.perform {
                            try message.managedObjectContext?.save()
                        }
                    }
                } catch {
                    title = ""
                }

                renderMessage()
                userActivity?.needsSave = true
            }
        } else {
            renderMessage()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        if didRender, let css = theme[string: "postsViewCSS"] {
            renderView.setThemeStylesheet(css)
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
    
    private enum CodingKey {
        static let composeViewController = "AwfulComposeViewController"
        static let message = "MessageKey"
        static let scrollFracton = "AwfulScrollFraction"
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(privateMessage.objectKey, forKey: CodingKey.message)
        coder.encode(composeVC, forKey: CodingKey.composeViewController)
        coder.encode(Float(renderView.scrollView.fractionalContentOffset.y), forKey: CodingKey.scrollFracton)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        composeVC = coder.decodeObject(of: MessageComposeViewController.self, forKey: CodingKey.composeViewController)
        composeVC?.delegate = self
        
        fractionalContentOffsetOnLoad = CGFloat(coder.decodeFloat(forKey: CodingKey.scrollFracton))
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MessageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
        
        composeVC = nil
    }
}

extension MessageViewController: RenderViewDelegate {
    func didFinishRenderingHTML(in view: RenderView) {
        if fractionalContentOffsetOnLoad > 0 {
            renderView.scrollToFractionalOffset(CGPoint(x: 0, y: fractionalContentOffsetOnLoad))
        }
        
        loadingView?.removeFromSuperview()
        loadingView = nil
        
        if embedTweets {
            renderView.embedTweets()
        }
    }
    
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            if fractionalContentOffsetOnLoad > 0 {
                renderView.scrollToFractionalOffset(CGPoint(x: 0, y: fractionalContentOffsetOnLoad))
            }
            
        case let didTapHeader as RenderView.BuiltInMessage.DidTapAuthorHeader:
            showUserActions(from: didTapHeader.frame)
            
        default:
            Log.w("ignoring unexpected message \(message)")
        }
    }
    
    func didTapLink(to url: URL, in view: RenderView) {
        if let route = try? AwfulRoute(url) {
            AppDelegate.instance.open(route: route)
        }
        else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        }
        else {
            UIApplication.shared.open(url)
        }
    }
    
    func renderProcessDidTerminate(in view: RenderView) {
        renderMessage()
    }
}

extension MessageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MessageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let messageKey = coder.decodeObject(of: PrivateMessageKey.self, forKey: CodingKey.message) else {
            return nil
        }
        
        let context = AppDelegate.instance.managedObjectContext
        let privateMessage = PrivateMessage.objectForKey(objectKey: messageKey, in: context)
        let messageVC = self.init(privateMessage: privateMessage)
        messageVC.restorationIdentifier = identifierComponents.last
        return messageVC
    }
}


private struct RenderModel: StencilContextConvertible {
    let context: [String: Any]
    
    init(message: PrivateMessage, stylesheet: String?) {
        let showAvatars = FoilDefaultStorage(Settings.showAvatars).wrappedValue
        let hiddenAvataruRL = showAvatars ? nil : message.from?.avatarURL
        var htmlContents: String? {
            guard let originalHTML = message.innerHTML else { return nil }
            let document = HTMLDocument(string: originalHTML)
            document.addAttributeToTweetLinks()
            if let username = FoilDefaultStorageOptional(Settings.username).wrappedValue {
                document.identifyQuotesCitingUser(named: username, shouldHighlight: true)
                document.identifyMentionsOfUser(named: username, shouldHighlight: true)
            }
            document.removeSpoilerStylingAndEvents()
            document.useHTML5VimeoPlayer()
            document.processImgTags(shouldLinkifyNonSmilies: !FoilDefaultStorage(Settings.loadImages).wrappedValue)
            if !FoilDefaultStorage(Settings.autoplayGIFs).wrappedValue {
                document.stopGIFAutoplay()
            }
            document.embedVideos()
            return document.bodyElement?.innerHTML
        }
        let visibleAvatarURL = showAvatars ? message.from?.avatarURL : nil
        
        context = [
            "fromUsername": message.fromUsername ?? "",
            "hiddenAvataruRL": hiddenAvataruRL as Any,
            "htmlContents": htmlContents as Any,
            "messageID": message.messageID,
            "regdate": message.from?.regdate as Any,
            "regdateRaw": message.from?.regdateRaw as Any,
            "seen": message.seen,
            "sentDate": message.sentDate as Any,
            "sentDateRaw": message.sentDateRaw as Any,
            "showAvatars": showAvatars,
            "stylesheet": stylesheet as Any,
            "visibleAvatarURL": visibleAvatarURL as Any]
    }
}
