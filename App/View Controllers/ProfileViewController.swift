//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import os
import UIKit
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ProfileViewController")

/// Shows detailed information about a particular user.
final class ProfileViewController: ViewController {

    private var didFetchProfile = false

    private lazy var renderView: RenderView = {
        let renderView = RenderView()
        renderView.delegate = self

        renderView.registerMessage(SendPrivateMessage.self)
        renderView.registerMessage(ShowHomepageActions.self)

        return renderView
    }()

    private var _liquidGlassTitleView: UIView?

    @available(iOS 26.0, *)
    private var liquidGlassTitleView: LiquidGlassTitleView {
        if _liquidGlassTitleView == nil {
            let titleView = LiquidGlassTitleView()
            titleView.title = user.username
            _liquidGlassTitleView = titleView
        }
        return _liquidGlassTitleView as! LiquidGlassTitleView
    }

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
    
    private func updateTitle() {
        title = user.username ?? LocalizedString("profile.default-title")
        if #available(iOS 26.0, *) {
            liquidGlassTitleView.title = title
        }
    }
    
    private func sendPrivateMessage() {
        let compose = MessageComposeViewController(recipient: user)
        present(compose.enclosingNavigationController, animated: true)
    }
    
    private func showActionsForHomepage(_ url: URL, from frame: CGRect) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: [SafariActivity(), ChromeActivity(url: url)])
        present(activity, animated: true)
        let popover = activity.popoverPresentationController
        popover?.sourceRect = frame
        popover?.sourceView = renderView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure extended layout to handle content under navbar properly in iOS 26
        extendedLayoutIncludesOpaqueBars = true

        view.addSubview(renderView)
        renderView.translatesAutoresizingMaskIntoConstraints = true
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renderView.scrollView.contentInsetAdjustmentBehavior = .never
        renderView.scrollView.delegate = self

        // Configure navigation bar for iOS 26 liquid glass effect
        if #available(iOS 26.0, *) {
            configureNavigationBarForLiquidGlass()
            configureLiquidGlassTitleView()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        renderProfile()

        // Update liquid glass title view for new theme
        if #available(iOS 26.0, *) {
            // Only update color if we're at the top (not scrolled)
            if renderView.scrollView.contentOffset.y <= -renderView.scrollView.adjustedContentInset.top {
                liquidGlassTitleView.textColor = theme["navigationBarTextColor"]
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Reset navbar to initial state for iOS 26
        if #available(iOS 26.0, *) {
            if let navController = navigationController as? NavigationController {
                navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))
            }
        }

        if presentingViewController != nil && navigationController?.viewControllers.count == 1 {
            navigationItem.leftBarButtonItem = .init(systemItem: .done, primaryAction: UIAction { _ in
                self.dismiss(animated: true, completion: nil)
            })
        }
        
        if !didFetchProfile {
            didFetchProfile = true
            
            Task {
                let userID = user.userID, username = user.username
                do {
                    let profile = try await ForumsClient.shared.profileUser(.userID(userID, username: username))
                    user = profile.user
                    renderProfile()
                } catch {
                    logger.error("error fetching user profile for \(username ?? "") (ID \(userID)): \(error)")
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        renderView.scrollView.flashScrollIndicators()
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
        // Apply safe area insets manually since we disabled automatic adjustment
        renderView.scrollView.contentInset.top = view.safeAreaInsets.top
        renderView.scrollView.contentInset.bottom = view.safeAreaInsets.bottom
        renderView.scrollView.scrollIndicatorInsets = renderView.scrollView.contentInset
    }

    @available(iOS 26.0, *)
    private func configureNavigationBarForLiquidGlass() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        guard let navController = navigationController as? NavigationController else { return }

        // Hide the custom bottom border from NavigationBar for liquid glass effect
        if let awfulNavigationBar = navigationBar as? NavigationBar {
            awfulNavigationBar.bottomBorderColor = .clear
        }

        // Start with opaque background
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        appearance.shadowColor = nil
        appearance.shadowImage = nil

        // Set text colors from theme
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

        // Set the back indicator image
        if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }

        // Apply to all states
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance

        // Set tintColor for theme
        navigationBar.tintColor = textColor

        // Initialize at scroll position 0 (opaque)
        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))

        // Force update
        navigationBar.setNeedsLayout()
    }

    @available(iOS 26.0, *)
    private func configureLiquidGlassTitleView() {
        // Set up the liquid glass title view
        liquidGlassTitleView.textColor = theme["navigationBarTextColor"]

        // Set font based on device type
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
            // At top: use theme color
            liquidGlassTitleView.textColor = theme["navigationBarTextColor"]
        } else if progress > 0.99 {
            // Fully scrolled: use nil for dynamic color adaptation
            liquidGlassTitleView.textColor = nil
        }
    }
    
    private func renderProfile() {
        let html: String = {
            guard let profile = user.profile else { return "" }
            do {
                return try StencilEnvironment.shared.renderTemplate(.profile, context: RenderModel(profile, theme: theme))
            }
            catch {
                logger.error("could not render profile HTML: \(error)")
                return ""
            }
        }()
        renderView.render(html: html, baseURL: baseURL)
    }
    
    private var baseURL: URL? {
        return ForumsClient.shared.baseURL
    }
    
    // MARK: Gunk
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}

private struct SendPrivateMessage: RenderViewMessage {
    static let messageName = "sendPrivateMessage"

    init?(rawMessage: WKScriptMessage, in renderView: RenderView) {
        assert(rawMessage.name == SendPrivateMessage.messageName)
    }
}

private struct ShowHomepageActions: RenderViewMessage {
    static let messageName = "showHomepageActions"
    
    /// The frame of the homepage row, in the render view's scroll view's coordinate system.
    let frame: CGRect
    
    /// Whatever's specified as the homepage. May not be parseable as a URL.
    let urlString: String

    init?(rawMessage: WKScriptMessage, in renderView: RenderView) {
        assert(rawMessage.name == ShowHomepageActions.messageName)
        
        guard
            let body = rawMessage.body as? [String: Any],
            let documentFrame = CGRect(renderViewMessage: body["frame"] as? [String: Double]),
            let urlString = body["url"] as? String
            else { return nil }

        frame = renderView.convertToRenderView(webDocumentRect: documentFrame)
        self.urlString = urlString
    }
}

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update navigation bar tint for iOS 26+ dynamic colors
        if #available(iOS 26.0, *) {
            // Calculate scroll progress for smooth transition
            let topInset = scrollView.adjustedContentInset.top
            let currentOffset = scrollView.contentOffset.y
            let topPosition = -topInset

            // Define transition zone (30 points for smooth fade)
            let transitionDistance: CGFloat = 30.0

            // Calculate progress (0.0 = fully at top, 1.0 = fully scrolled)
            let progress: CGFloat
            if currentOffset <= topPosition {
                // At or above the top
                progress = 0.0
            } else if currentOffset >= topPosition + transitionDistance {
                // Fully scrolled past transition zone
                progress = 1.0
            } else {
                // In transition zone - calculate smooth progress
                let distanceFromTop = currentOffset - topPosition
                progress = distanceFromTop / transitionDistance
            }

            // Update navigation controller
            if let navController = navigationController as? NavigationController {
                navController.updateNavigationBarTintForScrollProgress(NSNumber(value: Float(progress)))
            }

            // Update title text color based on scroll progress
            updateTitleViewTextColorForScrollProgress(progress)
        }
    }
}

extension ProfileViewController: RenderViewDelegate {
    func didFinishRenderingHTML(in view: RenderView) {
        // nop
    }
    
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case is SendPrivateMessage:
            sendPrivateMessage()
            
        case let message as ShowHomepageActions:
            guard let url = URL(string: message.urlString, relativeTo: baseURL) else {
                logger.info("ignoring unparseable supposed homepage URL: \(message.urlString)")
                return
            }
            
            showActionsForHomepage(url, from: message.frame)
            
        default:
            logger.warning("ignoring unexpected JavaScript message: \(type(of: message).messageName)")
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
        renderProfile()
    }
}


private struct RenderModel: StencilContextConvertible {
    let aboutMe: String?
    let aimName: String?
    let anyContactInfo: Bool
    let avatarURL: URL?
    let css: String
    let customTitleHTML: String?
    let dark: Bool
    let gender: String
    let homepageURL: URL?
    let icqName: String?
    let interests: String?
    let lastPost: Date?
    let location: String?
    let occupation: String?
    let postCount: Int
    let postRate: String?
    let privateMessagesWork: Bool
    let profilePictureURL: URL?
    let regdate: Date?
    let regdateRaw: String?
    let username: String?
    let yahooName: String?
    
    init(_ profile: Profile, theme: Theme) {
        let privateMessagesWork = profile.user.canReceivePrivateMessages && FoilDefaultStorage(Settings.canSendPrivateMessages).wrappedValue

        aboutMe = profile.aboutMe
        aimName = profile.aimName
        anyContactInfo = {
            return privateMessagesWork
                || !(profile.aimName ?? "").isEmpty
                || !(profile.icqName ?? "").isEmpty
                || !(profile.yahooName ?? "").isEmpty
                || profile.homepageURL != nil
        }()
        avatarURL = profile.user.avatarURL
        customTitleHTML = {
            let html = profile.user.customTitleHTML
            return html == "<br/>" ? nil : html
        }()
        // No good reason for profile.css to be loaded via theme: profile.less imports some of the posts view .less helpers, so it's easier to generate all the .css files in one place.
        css = try! theme.stylesheet(named: "profile")!
        dark = FoilDefaultStorage(Settings.darkMode).wrappedValue
        gender = profile.gender?.rawValue ?? LocalizedString("profile.default-gender")
        homepageURL = profile.homepageURL
        icqName = profile.icqName
        interests = profile.interests
        lastPost = profile.lastPostDate
        location = profile.location
        occupation = profile.occupation
        postCount = Int(profile.postCount)
        postRate = profile.postRate
        self.privateMessagesWork = privateMessagesWork
        profilePictureURL = profile.profilePictureURL
        regdate = profile.user.regdate
        regdateRaw = profile.user.regdateRaw
        username = profile.user.username
        yahooName = profile.yahooName
    }
    
    var context: [String: Any] {
        return [
            "aboutMe": aboutMe as Any,
            "aimName": aimName as Any,
            "anyContactInfo": anyContactInfo,
            "avatarURL": avatarURL as Any,
            "css": css,
            "customTitleHTML": customTitleHTML as Any,
            "dark": dark,
            "gender": gender,
            "homepageURL": homepageURL as Any,
            "icqName": icqName as Any,
            "interests": interests as Any,
            "lastPost": lastPost as Any,
            "location": location as Any,
            "occupation": occupation as Any,
            "postCount": postCount,
            "postRate": postRate as Any,
            "privateMessagesWork": privateMessagesWork,
            "profilePictureURL": profilePictureURL as Any,
            "regdate": regdate as Any,
            "regdateRaw": regdateRaw as Any,
            "username": username as Any,
            "yahooName": yahooName as Any]
    }
}
