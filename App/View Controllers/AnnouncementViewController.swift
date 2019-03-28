//  AnnouncementViewController.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import HTMLReader
import UIKit
import WebKit

private let Log = Logger.get()

/// Renders a Forums-wide announcement.
final class AnnouncementViewController: ViewController {
    
    private let announcement: Announcement
    private var announcementObserver: ManagedObjectObserver?
    private var clientCancellable: Cancellable?
    private var desiredFractionalContentOffsetAfterRendering: CGFloat?
    private let hadBeenSeenAlready: Bool

    private lazy var loadingView: LoadingView = {
        return LoadingView.loadingViewWithTheme(theme)
    }()

    private var messageViewController: MessageComposeViewController?

    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()

    private var state: State = .initialized {
        willSet {
            assert(state.canTransition(to: newValue))
        }
        didSet {
            Log.d("did transition from \(oldValue) to \(state)")

            didTransition(from: oldValue)
        }
    }

    private enum State {
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
                 (.renderingFirstTime, .rendered), (.renderingFirstTime, .rerendering),
                 (.failed, .rerendering),
                 (.rendered, .rerendering),
                 (.rerendering, .rendered), (.rerendering, .rerendering):
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

    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }

    private func setFractionalContentOffsetAfterRendering(fractionalContentOffset: CGFloat) {
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

        renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)

        announcementObserver = ManagedObjectObserver(object: announcement, didChange: { [weak self] (change) in
            guard let self = self else { return }
            switch change {
            case .delete:
                _ = self.navigationController?.popViewController(animated: true)

            case .update:
                switch (self.state, RenderModel(announcement: self.announcement, theme: self.theme, hadBeenSeenAlready: self.hadBeenSeenAlready)) {
                case (.loading, let model?):
                    self.state = .renderingFirstTime(model)

                case (.failed, let model?):
                    self.state = .rerendering(model)

                case (.rendered(let oldModel), let newModel?) where oldModel != newModel:
                    self.state = .rerendering(newModel)

                case (.initialized, _), (.loading, _), (.renderingFirstTime, _), (.rendered, _), (.failed, _), (.rerendering, _):
                    break
                }
            }
        })

        // TODO: long-press menu (links/images/embeds)

        let fetch = ForumsClient.shared.listAnnouncements()
        clientCancellable = fetch.cancellable
        fetch.promise
            .tap { Log.d("list announcements: \($0)") }
            .catch { [weak self] error in
                Log.e("couldn't list announcements: \(error)")

                guard let self = self else { return }

                if case .loading = self.state {
                    self.state = .failed(error)
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

        if isBeingDismissed || isMovingFromParent {
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
                let rendering = try StencilEnvironment.shared.renderTemplate(.announcement, context: model)
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

    private func didTapAuthorHeaderInPost(at postIndex: Int, frame: CGRect) {
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

        if UserDefaults.standard.loggedInUserCanSendPrivateMessages
            && user.canReceivePrivateMessages
            && user.userID != UserDefaults.standard.loggedInUserID
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
            sourceView.pointee = self.renderView
        }

        present(actionVC, animated: true)
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
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
        announcementVC.restorationIdentifier = identifierComponents.last
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

private struct RenderModel: CustomDebugStringConvertible, Equatable, StencilContextConvertible {
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
            document.removeSpoilerStylingAndEvents()
            document.removeEmptyEditedByParagraphs()
            document.useHTML5VimeoPlayer()
            if let username = UserDefaults.standard.loggedInUsername {
                document.identifyMentionsOfUser(named: username, shouldHighlight: true)
                document.identifyQuotesCitingUser(named: username, shouldHighlight: true)
            }
            document.processImgTags(shouldLinkifyNonSmilies: !UserDefaults.standard.showImages)
            if !UserDefaults.standard.automaticallyPlayGIFs {
                document.stopGIFAutoplay()
            }
            return document.bodyElement?.innerHTML ?? ""
        }()

        postedDate = announcement.postedDate

        roles = announcement.author?.roles(in: announcement) ?? []

        showsAvatar = UserDefaults.standard.showAuthorAvatars
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
        @unknown default:
            assertionFailure("handle unknown user interface idiom")
            return "iphone"
        }
    }

    var visibleAvatarURL: URL? {
        return showsAvatar ? avatarURL : nil
    }

    var debugDescription: String {
        func firstBit(of s: String) -> String {
            return String(s.lazy
                .map { (c: Character) -> Character in c == "\n" ? " " : c }
                .prefix(20))
        }
        return "AnnouncementViewController.RenderModel(css: \(firstBit(of: css)), html: \(firstBit(of: innerHTML)))"
    }

    var context: [String : Any] {
        return [
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
            "visibleAvatarURL": visibleAvatarURL as Any]
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
    func didFinishRenderingHTML(in view: RenderView) {
        switch state {
        case .renderingFirstTime(let model), .rerendering(let model):
            state = .rendered(model)
            
        default:
            Log.w("ignoring didFinishRenderingHTML in unexpected state \(state)")
        }
    }
    
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
            didTapAuthorHeaderInPost(at: message.postIndex, frame: message.frame)

        default:
            Log.w("ignoring unexpected JavaScript message: \(type(of: message).messageName)")
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
            UIApplication.shared.openURL(url)
        }
    }
    
    func renderProcessDidTerminate(in view: RenderView) {
        switch state {
        case .initialized, .loading:
            break
            
        case .renderingFirstTime(let model):
            state = .rerendering(model)
            
        case .failed:
            if let model = RenderModel(announcement: announcement, theme: theme, hadBeenSeenAlready: hadBeenSeenAlready) {
                state = .rerendering(model)
            }
            
        case .rendered(let model):
            state = .rerendering(model)
            
        case .rerendering(let model):
            state = .rerendering(model)
        }
    }
}
