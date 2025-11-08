//  MessageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import HTMLReader
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageViewController")

/// Displays a single private message.
final class MessageViewController: ViewController {
    
    @FoilDefaultStorage(Settings.autoplayGIFs) private var autoplayGIFs
    private var cancellables: Set<AnyCancellable> = []
    private var composeVC: MessageComposeViewController?
    private var didLoadOnce = false
    private var didRender = false
    @FoilDefaultStorage(Settings.embedBlueskyPosts) private var embedBlueskyPosts
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    private var fractionalContentOffsetOnLoad: CGFloat = 0
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var loadingView: LoadingView?
    private lazy var oEmbedFetcher: OEmbedFetcher = .init()
    private let privateMessage: PrivateMessage
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages

    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()

    private var _liquidGlassTitleView: UIView?

    @available(iOS 26.0, *)
    private var liquidGlassTitleView: LiquidGlassTitleView {
        if _liquidGlassTitleView == nil {
            let titleView = LiquidGlassTitleView()
            titleView.title = privateMessage.subject
            _liquidGlassTitleView = titleView
        }
        return _liquidGlassTitleView as! LiquidGlassTitleView
    }
    
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
        didSet {
            if #available(iOS 26.0, *) {
                liquidGlassTitleView.title = title
            } else {
                navigationItem.titleLabel.text = title
            }
        }
    }
    
    private func renderMessage() {
        do {
            let model = RenderModel(message: privateMessage, stylesheet: theme["postsViewCSS"])
            let rendering = try StencilEnvironment.shared.renderTemplate(.privateMessage, context: model)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            logger.error("failed to render private message: \(error)")
            
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
    
    private func fetchOEmbed(url: URL, id: String) {
        Task {
            let callbackData = await oEmbedFetcher.fetch(url: url, id: id)
            renderView.didFetchOEmbed(id: id, response: callbackData)
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

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        extendedLayoutIncludesOpaqueBars = true

        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renderView.scrollView.contentInsetAdjustmentBehavior = .never
        renderView.scrollView.delegate = self
        view.insertSubview(renderView, at: 0)

        if #available(iOS 26.0, *) {
            configureNavigationBarForLiquidGlass()
            configureLiquidGlassTitleView()
        }
        
        renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        renderView.registerMessage(RenderView.BuiltInMessage.FetchOEmbedFragment.self)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressWebView))
        longPress.delegate = self
        renderView.addGestureRecognizer(longPress)

        $embedBlueskyPosts
            .dropFirst()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderView.embedBlueskyPosts() }
            .store(in: &cancellables)

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

        if #available(iOS 26.0, *) {
            if renderView.scrollView.contentOffset.y <= -renderView.scrollView.adjustedContentInset.top {
                liquidGlassTitleView.textColor = theme["navigationBarTextColor"]
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 26.0, *) {
            if let navController = navigationController as? NavigationController {
                navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUserActivity()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewContentInsets()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateScrollViewContentInsets()
    }

    private func updateScrollViewContentInsets() {
        renderView.scrollView.contentInset.top = view.safeAreaInsets.top
        renderView.scrollView.contentInset.bottom = view.safeAreaInsets.bottom
        renderView.scrollView.scrollIndicatorInsets = renderView.scrollView.contentInset
    }

    @available(iOS 26.0, *)
    private func configureNavigationBarForLiquidGlass() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        guard let navController = navigationController as? NavigationController else { return }

        if let awfulNavigationBar = navigationBar as? NavigationBar {
            awfulNavigationBar.bottomBorderColor = .clear
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        appearance.shadowColor = nil
        appearance.shadowImage = nil

        let textColor: UIColor = theme["navigationBarTextColor"]!
        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]

        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        let buttonAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: buttonFont
        ]
        appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes

        if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance

        navigationBar.tintColor = textColor

        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))

        navigationBar.setNeedsLayout()
    }

    @available(iOS 26.0, *)
    private func configureLiquidGlassTitleView() {
        liquidGlassTitleView.textColor = theme["navigationBarTextColor"]

        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            liquidGlassTitleView.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        default:
            liquidGlassTitleView.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        }

        navigationItem.titleView = liquidGlassTitleView
    }

    @available(iOS 26.0, *)
    private func updateTitleViewTextColorForScrollProgress(_ progress: CGFloat) {
        if progress < 0.01 {
            liquidGlassTitleView.textColor = theme["navigationBarTextColor"]
        } else if progress > 0.99 {
            liquidGlassTitleView.textColor = nil
        }
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

        if embedBlueskyPosts {
            renderView.embedBlueskyPosts()
        }
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
            
        case let message as RenderView.BuiltInMessage.FetchOEmbedFragment:
            fetchOEmbed(url: message.url, id: message.id)
            
        default:
            let description = "\(message)"
            logger.warning("ignoring unexpected message \(description)")
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

extension MessageViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #available(iOS 26.0, *) {
            let topInset = scrollView.adjustedContentInset.top
            let currentOffset = scrollView.contentOffset.y
            let topPosition = -topInset

            let transitionDistance: CGFloat = 30.0

            let progress: CGFloat
            if currentOffset <= topPosition {
                progress = 0.0
            } else if currentOffset >= topPosition + transitionDistance {
                progress = 1.0
            } else {
                let distanceFromTop = currentOffset - topPosition
                progress = distanceFromTop / transitionDistance
            }

            if let navController = navigationController as? NavigationController {
                navController.updateNavigationBarTintForScrollProgress(NSNumber(value: Float(progress)))
            }

            updateTitleViewTextColorForScrollProgress(progress)
        }
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
            document.addAttributeToBlueskyLinks()
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
