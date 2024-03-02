//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import UIKit
import WebKit

private let Log = Logger.get()

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
        view.addSubview(renderView)
        renderView.translatesAutoresizingMaskIntoConstraints = true
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        super.viewDidLoad()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderProfile()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
                    Log.e("error fetching user profile for \(username ?? "") (ID \(userID)): \(error)")
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        renderView.scrollView.flashScrollIndicators()
    }
    
    private func renderProfile() {
        let html: String = {
            guard let profile = user.profile else { return "" }
            do {
                return try StencilEnvironment.shared.renderTemplate(.profile, context: RenderModel(profile, theme: theme))
            }
            catch {
                Log.e("could not render profile HTML: \(error)")
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
                Log.i("ignoring unparseable supposed homepage URL: \(message.urlString)")
                return
            }
            
            showActionsForHomepage(url, from: message.frame)
            
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
