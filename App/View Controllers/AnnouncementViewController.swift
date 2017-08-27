//  AnnouncementViewController.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import HTMLReader
import Mustache
import UIKit
import WebKit

private let Log = Logger.get(level: .debug)

final class AnnouncementViewController: ViewController {
    fileprivate let announcement: Announcement
    private var announcementObserver: ManagedObjectObserver?
    private var clientCancellable: Cancellable?
    private var desiredFractionalContentOffsetAfterRendering: CGFloat?
    private let hadBeenSeenAlready: Bool

    fileprivate lazy var loadingView: LoadingView = {
        return LoadingView.loadingViewWithTheme(self.theme)
    }()

    fileprivate var messageViewController: MessageComposeViewController?

    fileprivate lazy var renderView: RenderView = {
        let view = RenderView(frame: CGRect(origin: .zero, size: self.view.bounds.size))
        view.delegate = self
        return view
    }()

    fileprivate var state: State = .initialized {
        willSet {
            assert(state.canTransition(to: newValue))
        }
        didSet {
            Log.d("did transition from \(oldValue) to \(state)")

            didTransition(from: oldValue)
        }
    }

    fileprivate enum State {
        case initialized
        case loading
        case renderingFirstTime(RenderModel)
        case failed(Error)
        case rendered(RenderModel)
        case rerendering(RenderModel)

        func canTransition(to newState: State) -> Bool {
            switch (self, newState) {
            case (.initialized, .loading),
                 (.loading, .renderingFirstTime), (.loading, .failed),
                 (.renderingFirstTime, .rendered),
                 (.failed, .rerendering),
                 (.rendered, .rerendering),
                 (.rerendering, .rendered):
                return true

            case (.initialized, _), (.loading, _), (.renderingFirstTime, _), (.failed, _), (.rendered, _), (.rerendering, _):
                return false
            }
        }
    }

    init(announcement: Announcement) {
        self.announcement = announcement
        hadBeenSeenAlready = announcement.hasBeenSeen
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        restorationClass = type(of: self)

        title = !announcement.title.isEmpty
            ? announcement.title
            : LocalizedString("announcements.title")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }

    fileprivate func setFractionalContentOffsetAfterRendering(fractionalContentOffset: CGFloat) {
        switch state {
        case .initialized, .loading, .renderingFirstTime, .rerendering:
            desiredFractionalContentOffsetAfterRendering = fractionalContentOffset

        case .rendered:
            scrollToFractionalOffset(fractionalContentOffset)

        case .failed:
            Log.w("ignoring attempt set fractional content offset; announcement failed to load")
        }
    }

    private func scrollToFractionalOffset(_ fractionalOffsetY: CGFloat) {
        renderView.scrollToFractionalOffset(CGPoint(x: 0, y: fractionalOffsetY))

        desiredFractionalContentOffsetAfterRendering = nil
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(renderView, at: 0)

        renderView.registerJavaScriptMessage(RenderView.JavaScriptMessage.DidRender.self)
        renderView.registerJavaScriptMessage(RenderView.JavaScriptMessage.DidTapAuthorHeader.self)

        announcementObserver = ManagedObjectObserver(object: announcement, didChange: { [weak self] (change) in
            guard let sself = self else { return }
            switch change {
            case .delete:
                _ = sself.navigationController?.popViewController(animated: true)

            case .update:
                switch (sself.state, RenderModel(announcement: sself.announcement, theme: sself.theme, hadBeenSeenAlready: sself.hadBeenSeenAlready)) {
                case (.loading, let model?):
                    sself.state = .renderingFirstTime(model)

                case (.failed, let model?):
                    sself.state = .rerendering(model)

                case (.rendered(let oldModel), let newModel?) where oldModel != newModel:
                    sself.state = .rerendering(newModel)

                case (.initialized, _), (.loading, _), (.renderingFirstTime, _), (.rendered, _), (.failed, _), (.rerendering, _):
                    break
                }
            }
        })

        // TODO: long-press menu (links/images/embeds)
        // TODO: network activity indicator

        let fetch = ForumsClient.shared.listAnnouncements()
        clientCancellable = fetch.cancellable
        fetch.promise
            .tap { Log.d("list announcements: \($0)") }
            .catch { [weak self] error in
                Log.e("couldn't list announcements: \(error)")

                guard let sself = self else { return }

                if case .loading = sself.state {
                    sself.state = .failed(error)
                }
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle

        switch (state, RenderModel(announcement: announcement, theme: theme, hadBeenSeenAlready: hadBeenSeenAlready)) {
        case (.initialized, nil):
            state = .loading

        case (.initialized, let renderModel?):
            state = .loading
            state = .renderingFirstTime(renderModel)

        case (.rendered(let oldModel), let newModel?) where oldModel != newModel:
            state = .rerendering(newModel)

        default:
            break
        }

        messageViewController?.themeDidChange()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isBeingDismissed || isMovingFromParentViewController {
            clientCancellable?.cancel()
        }
    }

    private func didTransition(from oldState: State) {
        switch (oldState, state) {
        case (_, .loading):
            loadingView.alpha = 1
            view.addSubview(loadingView)

        case (_, .renderingFirstTime(let model)), (_, .rerendering(let model)):
            do {
                let template = try Template(named: "Announcement")
                template.extendBaseContext([
                    "formatters": [
                        "announcementDate": DateFormatter.announcementDateFormatter,
                        "regdate": DateFormatter.regDateFormatter]])
                if AwfulSettings.shared().fontScale != 100 {
                    template.register(AwfulSettings.shared().fontScale, forKey: "fontScalePercentage")
                }
                let rendering = try template.render(model)
                renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
            }
            catch {
                Log.e("Failure rendering announcement: \(error)")

                // TODO: show error nicer
                renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
            }

        case (.renderingFirstTime, .rendered), (.rerendering, .rendered):
            if !announcement.hasBeenSeen {
                announcement.hasBeenSeen = true
                try! announcement.managedObjectContext?.save()
            }

            hideLoadingView()

            if let fractionalOffset = desiredFractionalContentOffsetAfterRendering {
                scrollToFractionalOffset(fractionalOffset)
            }

        case (_, .failed(let error)):
            present(UIAlertController(networkError: error), animated: true)

        case (_, .initialized), (_, .rendered):
            break
        }
    }

    private func hideLoadingView() {
        guard loadingView.superview != nil else { return }

        UIView.animate(withDuration: 0.2, animations: {
            self.loadingView.alpha = 0
        }, completion: { didFinish in
            self.loadingView.removeFromSuperview()
        })
    }

    // MARK: Actions

    fileprivate func didTapAuthorHeaderInPost(at postIndex: Int, frame: CGRect) {
        assert(postIndex == 0, "why was there more than one announcement?")
        guard let user = announcement.author else {
            Log.e("tapped author header but announcement has no author?")
            return
        }

        var items: [IconActionItem] = []

        items.append(IconActionItem(.userProfile, block: {
            let profileVC = ProfileViewController(user: user)
            self.present(profileVC.enclosingNavigationController, animated: true)
        }))

        if AwfulSettings.shared().canSendPrivateMessages
            && user.canReceivePrivateMessages
            && user.userID != AwfulSettings.shared().userID
        {
            items.append(IconActionItem(.sendPrivateMessage, block: {
                let messageVC = MessageComposeViewController(recipient: user)
                self.messageViewController = messageVC
                messageVC.delegate = self
                messageVC.restorationIdentifier = "New PM from announcement view"
                self.present(messageVC.enclosingNavigationController, animated: true)
            }))
        }

        items.append(IconActionItem(.rapSheet, block: {
            let rapSheetVC = RapSheetViewController(user: user)
            if self.traitCollection.userInterfaceIdiom == .pad || self.navigationController == nil {
                self.present(rapSheetVC.enclosingNavigationController, animated: true)
            }
            else {
                self.navigationController?.pushViewController(rapSheetVC, animated: true)
            }
        }))

        let actionVC = InAppActionViewController()
        actionVC.items = items

        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
            sourceRect.pointee = frame
            sourceView.pointee = self.renderView.scrollView
        }

        present(actionVC, animated: true)
    }
}

extension AnnouncementViewController: UIViewControllerRestoration {
    private enum StateKey {
        static let announcementListIndex = "announcement list index"
        static let fractionalContentOffsetY = "fractional content offset y-value"
        static let messageViewController = "message view controller"
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(announcement.listIndex, forKey: StateKey.announcementListIndex)
        coder.encode(messageViewController, forKey: StateKey.messageViewController)
        coder.encode(Float(renderView.scrollView.fractionalContentOffset.y), forKey: StateKey.fractionalContentOffsetY)
    }

    static func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        let listIndex = coder.decodeInt32(forKey: StateKey.announcementListIndex)
        let fetchRequest = NSFetchRequest<Announcement>(entityName: Announcement.entityName())
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "%K = %d", #keyPath(Announcement.listIndex), listIndex)
        let maybeAnnouncement: Announcement?
        do {
            maybeAnnouncement = try AppDelegate.instance.managedObjectContext.fetch(fetchRequest).first
        }
        catch {
            Log.e("error attempting to fetch announcement: \(error)")
            return nil
        }

        guard let announcement = maybeAnnouncement else {
            Log.w("couldn't find announcement at list index \(listIndex); skipping announcement view state restoration")
            return nil
        }

        let announcementVC = AnnouncementViewController(announcement: announcement)
        announcementVC.restorationIdentifier = identifierComponents.last as? String
        return announcementVC
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        messageViewController = coder.decodeObject(of: MessageComposeViewController.self, forKey: StateKey.messageViewController)
        messageViewController?.delegate = self

        let fractionalOffset = coder.decodeFloat(forKey: StateKey.fractionalContentOffsetY)
        setFractionalContentOffsetAfterRendering(fractionalContentOffset: CGFloat(fractionalOffset))
    }
}

fileprivate struct RenderModel: CustomDebugStringConvertible, Equatable, MustacheBoxable {
    let authorRegdate: Date?
    let authorRolesDescription: String
    let authorUserID: String?
    let authorUsername: String
    private let avatarURL: URL?
    let css: String
    let hasBeenSeen: Bool
    let innerHTML: String
    let postedDate: Date?
    let roles: [String]
    private let showsAvatar: Bool

    init?(announcement: Announcement, theme: Theme, hadBeenSeenAlready: Bool) {
        guard !announcement.bodyHTML.isEmpty else { return nil }

        authorRegdate = announcement.author?.regdate ?? announcement.authorRegdate

        authorRolesDescription = (announcement.author?.accessibilityRoles(in: announcement) ?? [])
            .joined(separator: "; ")

        authorUserID = announcement.author?.userID

        authorUsername = announcement.author?.username ?? announcement.authorUsername

        avatarURL = announcement.author?.avatarURL
            ?? extractAvatarURL(fromCustomTitleHTML: announcement.authorCustomTitleHTML)

        css = theme["postsViewCSS"] as String? ?? ""

        hasBeenSeen = announcement.hasBeenSeen && hadBeenSeenAlready

        innerHTML = {
            let document = HTMLDocument(string: announcement.bodyHTML)
            RemoveSpoilerStylingAndEvents(document)
            RemoveEmptyEditedByParagraphs(document)
            UseHTML5VimeoPlayer(document)
            HighlightQuotesOfPostsByUserNamed(document, AwfulSettings.shared().username)
            ProcessImgTags(document, !AwfulSettings.shared().showImages)
            if !AwfulSettings.shared().autoplayGIFs {
                StopGifAutoplay(document)
            }
            return document.bodyElement?.innerHTML ?? ""
        }()

        postedDate = announcement.postedDate

        roles = announcement.author?.roles(in: announcement) ?? []

        showsAvatar = AwfulSettings.shared().showAvatars
    }

    var hiddenAvatarURL: URL? {
        return showsAvatar ? nil : avatarURL
    }

    var userInterfaceIdiom: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return "ipad"
        case .phone, .carPlay, .tv, .unspecified:
            return "iphone"
        }
    }

    var visibleAvatarURL: URL? {
        return showsAvatar ? avatarURL : nil
    }

    var debugDescription: String {
        func firstBit(of s: String) -> String {
            return String(s.characters.lazy.map { $0 == "\n" ? " " : $0 }.prefix(20))
        }
        return "AnnouncementViewController.RenderModel(css: \(firstBit(of: css)), html: \(firstBit(of: innerHTML)))"
    }

    static func == (lhs: RenderModel, rhs: RenderModel) -> Bool {
        return lhs.authorRegdate == rhs.authorRegdate
            && lhs.authorRolesDescription == rhs.authorRolesDescription
            && lhs.authorUsername == rhs.authorUsername
            && lhs.avatarURL == rhs.avatarURL
            && lhs.css == rhs.css
            && lhs.hasBeenSeen == rhs.hasBeenSeen
            && lhs.innerHTML == rhs.innerHTML
            && lhs.postedDate == rhs.postedDate
            && lhs.roles == rhs.roles
            && lhs.showsAvatar == rhs.showsAvatar
    }

    var mustacheBox: MustacheBox {
        return Box([
            "authorRegdate": authorRegdate as Any,
            "authorRolesDescription": authorRolesDescription,
            "authorUserID": authorUserID as Any,
            "authorUsername": authorUsername,
            "hasBeenSeen": hasBeenSeen,
            "hiddenAvatarURL": hiddenAvatarURL as Any,
            "innerHTML": innerHTML,
            "postedDate": postedDate as Any,
            "roles": roles,
            "stylesheet": css,
            "userInterfaceIdiom": userInterfaceIdiom,
            "visibleAvatarURL": visibleAvatarURL as Any])
    }
}

extension AnnouncementViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true)

        if !shouldKeepDraft {
            messageViewController = nil
        }
    }
}

extension AnnouncementViewController: RenderViewDelegate {
    func didReceive(javaScriptMessage: RenderViewJavaScriptMessage, in view: RenderView) {
        switch javaScriptMessage {
        case is RenderView.JavaScriptMessage.DidRender:
            switch state {
            case .renderingFirstTime(let model), .rerendering(let model):
                state = .rendered(model)

            default:
                Log.w("ignoring didRender in unexpected state \(state)")
            }

        case let message as RenderView.JavaScriptMessage.DidTapAuthorHeader:
            didTapAuthorHeaderInPost(at: message.postIndex, frame: message.frame)

        default:
            Log.w("ignoring unexpected JavaScript message: \(type(of: javaScriptMessage).messageName)")
        }
    }

    func didTapLink(to url: URL, in view: RenderView) {
        if let awfulURL = url.awfulURL {
            AppDelegate.instance.openAwfulURL(awfulURL)
        }
        else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        }
        else {
            UIApplication.shared.openURL(url)
        }
    }
}

final class RenderView: UIView {
    weak var delegate: RenderViewDelegate?
    var scrollView: UIScrollView { return webView.scrollView }

    fileprivate var registeredJavaScriptMessages: [RenderViewJavaScriptMessage.Type] = []

    fileprivate lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()

        for filename in ["Announcement.js", "RenderView.js"] {
            let jsURL = Bundle(for: RenderView.self).url(forResource: filename, withExtension: nil) !! "Please include \(filename)"
            let js = try! String(contentsOf: jsURL)
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(userScript)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        return webView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        webView.frame = CGRect(origin: .zero, size: self.frame.size)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(html: String, baseURL: URL?) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    /**
     Scrolls past `fractionalOffset` of the render view's content size.
     
     `scrollToFractionalOffset(_:)` works whenever directly setting the scroll view's `contentOffset` works, but in addition it may work even when the scroll view's `contentSize` is zero.
     
     - Seealso: `UIScrollView.fractionalContentOffset`.
     */
    func scrollToFractionalOffset(_ fractionalOffset: CGPoint) {
        let js = "window.scrollTo(document.body.scrollWidth * \(fractionalOffset.x), "
            + "document.body.scrollHeight * \(fractionalOffset.y))"
        webView.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error {
                Log.e("error attempting to scroll: \(error)")
            }
        })
    }
}

extension RenderView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated
            || navigationAction.isAttemptingToHijackWebView
            || navigationAction.targetFrame == nil else
        {
            return decisionHandler(.allow)
        }

        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }

        decisionHandler(.cancel)

        delegate?.didTapLink(to: url, in: self)
    }
}

/**
 A message that can be sent from the render view's JavaScript.

 This allows communication from the web view to the native side. For the reverse direction, use methods on `WKWebView`.
 
 - Seealso: `WKWebView.evaluateJavaScript(_:completionHandler:)`
 */
protocol RenderViewJavaScriptMessage {

    /// The name of the message. JavaScript can send this message by calling `window.webkit.messageHandlers.messageName.postMessage`, replacing `messageName` with the value returned here.
    static var messageName: String { get }

    /// - Returns: `nil` if the required message body couldn't be read in `message`.
    init?(_ message: WKScriptMessage)
}

extension RenderView: WKScriptMessageHandler {
    func registerJavaScriptMessage(_ messageType: RenderViewJavaScriptMessage.Type) {
        registeredJavaScriptMessages.append(messageType)

        webView.configuration.userContentController.add(ScriptMessageHandlerWeakTrampoline(self), name: messageType.messageName)
    }

    func unregisterJavaScriptMessage(_ messageType: RenderViewJavaScriptMessage.Type) {
        guard let i = registeredJavaScriptMessages.index(where: { $0 == messageType }) else {
                return
        }

        let messageType = registeredJavaScriptMessages.remove(at: i)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageType.messageName)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Log.d("received message from JavaScript: \(message.name)")

        let messageType = registeredJavaScriptMessages.first { $0.messageName == message.name }
        if let message = messageType?.init(message) {
            delegate?.didReceive(javaScriptMessage: message, in: self)
        }
        else {
            Log.w("ignoring unexpected message from JavaScript: \(message.name). Did you forget to register a JavaScript message with the RenderView?")
        }
    }

    /**
     Messages that are already present in `RenderView.js` and immediately available to be registered in a `RenderView`. You can add your own messages by conforming to `RenderViewJavaScriptMessage` and registering your message type with `RenderView`.
     
     - Seealso: `RenderViewJavaScriptMessage`
     - Seealso: `RenderView.registerJavaScriptMessage(_:)`
     */
    enum JavaScriptMessage {

        /// Sent from the web view once the document has more or less loaded (`DOMContentLoaded`).
        struct DidRender: RenderViewJavaScriptMessage {
            static let messageName = "didRender"

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidRender.messageName)
            }
        }

        /// Sent from the web view when the user taps the header in a post.
        struct DidTapAuthorHeader: RenderViewJavaScriptMessage {
            static let messageName = "didTapAuthorHeader"

            /// The frame of the tapped header, in the render view's scroll view's coordinate system.
            let frame: CGRect

            /// The index of the tapped post, where `0` is the first post in the render view.
            let postIndex: Int

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidTapAuthorHeader.messageName)
                
                guard
                    let body = message.body as? [String: Any],
                    let frame = body["frame"] as? [String: Double],
                    let x = frame["x"],
                    let y = frame["y"],
                    let width = frame["width"],
                    let height = frame["height"],
                    let postIndex = body["postIndex"] as? Int
                    else { return nil }

                self.frame = CGRect(x: x, y: y, width: width, height: height)
                self.postIndex = postIndex
            }
        }

        /// Sent from the web view when the user taps the ⋯ button in a post.
        struct DidTapPostActionButton: RenderViewJavaScriptMessage {
            static let messageName = "didTapPostActionButton"

            /// The frame of the tapped button, in the render view's scroll view's coordinate system.
            let frame: CGRect

            /// The index of the tapped post, where `0` is the first post in the render view.
            let postIndex: Int

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidTapPostActionButton.messageName)

                guard
                    let body = message.body as? [String: Any],
                    let frame = body["frame"] as? [String: Double],
                    let x = frame["x"],
                    let y = frame["y"],
                    let width = frame["width"],
                    let height = frame["height"],
                    let postIndex = body["postIndex"] as? Int
                    else { return nil }

                self.frame = CGRect(x: x, y: y, width: width, height: height)
                self.postIndex = postIndex
            }
        }
    }
}

protocol RenderViewDelegate: class {
    func didReceive(javaScriptMessage: RenderViewJavaScriptMessage, in view: RenderView)
    func didTapLink(to url: URL, in view: RenderView)
}

final class Logger {
    var level: Level
    private let name: String

    enum Level {
        case debug, info, warning, error

        fileprivate var abbreviation: String {
            switch self {
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .warning:
                return "WARN"
            case .error:
                return "ERROR"
            }
        }

        static func >= (lhs: Level, rhs: Level) -> Bool {
            switch (lhs, rhs) {
                case (.debug, .debug),
                     (.info, .debug), (.info, .info),
                     (.warning, .debug), (.warning, .info), (.warning, .warning),
                     (.error, _):
                return true

            case (.debug, _), (.info, _), (.warning, _):
                return false
            }
        }
    }

    private init(name: String, level: Level = .info) {
        self.name = name
        self.level = level
    }

    private static var loggers: [String: Logger] = [:]

    static func get(_ name: String? = nil, level: Level = .info, file: String = #file) -> Logger {
        let name = name
            ?? file.components(separatedBy: "/").last?.components(separatedBy: ".").dropLast().last
            ?? ""

        if let logger = loggers[name] {
            return logger
        }

        let logger = Logger(name: name, level: level)
        loggers[name] = logger

        return logger
    }

    private func log(level: Level, message: () -> String, file: String, line: Int) {
        guard level >= self.level else { return }
        print("[\(name)] \(file):L\(line):\(level.abbreviation): \(message())")
    }

    func d(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, file: file, line: line)
    }

    func i(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, file: file, line: line)
    }

    func w(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, file: file, line: line)
    }

    func e(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, file: file, line: line)
    }
}

/// WKUserContentController takes a strong reference to its script handlers. That makes a retain cycle when your script handler has a strong reference to the web view. The trampoline breaks the cycle.
final class ScriptMessageHandlerWeakTrampoline: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

extension WKNavigationAction {
    /**
     Whether the navigation appears to be an embed trying to navigate away.
     
     Some embeds (Twitter, YouTube) try to navigate somewhere when the user taps a thing, and for whatever reason it doesn't get counted as a click event.
     */
    var isAttemptingToHijackWebView: Bool {
        guard case .other = navigationType else { return false }

        // TODO: worth considering `targetFrame` and/or `isMainFrame`?

        guard let url = request.url, let host = url.host?.lowercased() else { return false }
        if host.hasSuffix("www.youtube.com"), url.path.lowercased().hasPrefix("/watch") {
            return true
        }
        else if
            host.hasSuffix("twitter.com"),
            let thirdComponent = url.pathComponents.dropFirst(2).first,
            thirdComponent.lowercased() == "status"
        {
            return true
        }
        else {
            return false
        }
    }
}

final class ManagedObjectObserver {
    private let didChange: (Change) -> Void
    private var token: NSObjectProtocol?

    enum Change {
        case delete, update
    }

    init?(object: NSManagedObject, didChange: @escaping (Change) -> Void) {
        guard let context = object.managedObjectContext else { return nil }

        self.didChange = didChange

        token = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: nil) { [unowned self] notification in
            let notification = ContextObjectsDidChangeNotification(notification)
            guard let change = Change(object: object, notification: notification) else { return }
            self.didChange(change)
        }
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

struct ContextObjectsDidChangeNotification {
    private let notification: Notification

    init(_ notification: Notification) {
        assert(notification.name == .NSManagedObjectContextObjectsDidChange)
        self.notification = notification
    }

    private func objects(forKey key: String) -> Set<NSManagedObject> {
        return notification.userInfo?[key] as? Set<NSManagedObject> ?? []
    }

    var deletedObjects: Set<NSManagedObject> {
        return objects(forKey: NSDeletedObjectsKey)
    }

    var didInvalidateAllObjects: Bool {
        return notification.userInfo?[NSInvalidatedAllObjectsKey] != nil
    }

    var invalidatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSInvalidatedObjectsKey)
    }

    var refreshedObjects: Set<NSManagedObject> {
        return objects(forKey: NSRefreshedObjectsKey)
    }

    var updatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSUpdatedObjectsKey)
    }
}

private extension ManagedObjectObserver.Change {
    init?(object: NSManagedObject, notification: ContextObjectsDidChangeNotification) {
        if notification.didInvalidateAllObjects
            || notification.invalidatedObjects.contains(object)
            || notification.deletedObjects.contains(object)
        {
            self = .delete
        }
        else if notification.refreshedObjects.contains(object) || notification.updatedObjects.contains(object) {
            self = .update
        }
        else {
            return nil
        }
    }
}

infix operator !!: NilCoalescingPrecedence

extension Optional {
    /// Performs a forced unwrap operation, returning
    /// the wrapped value of an `Optional` instance
    /// or performing a `fatalError` with the string
    /// on the rhs of the operator.
    ///
    /// Forced unwrapping unwraps the left-hand side
    /// if it has a value or errors if it does not.
    /// The result of a successful operation will
    /// be the same type as the wrapped value of its
    /// left-hand side argument.
    ///
    /// This operator uses short-circuit evaluation:
    /// The `optional` lhs is checked first, and the
    /// `fatalError` is called only if the left hand
    /// side is nil. For example:
    ///
    ///    guard !lastItem.isEmpty else { return }
    ///    let lastItem = array.last !! "Array guaranteed to be non-empty because..."
    ///
    ///    let willFail = [].last !! "Array should have been guaranteed to be non-empty because..."
    ///
    ///
    /// In this example, `lastItem` is assigned the last value
    /// in `array` because the array is guaranteed to be non-empty.
    /// `willFail` is never assigned as the last item in an empty array is nil.
    /// - Parameters:
    ///   - optional: An optional value.
    ///   - message: A message to emit via `fatalError` after
    ///     failing to unwrap the optional.
    static func !!(optional: Optional, errorMessage: @autoclosure () -> String) -> Wrapped {
        if let value = optional { return value }
        fatalError(errorMessage())
    }
}
