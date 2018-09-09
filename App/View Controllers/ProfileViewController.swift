//  ProfileViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import AwfulCore
import Mustache
import PromiseKit
import TUSafariActivity
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
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    private func updateTitle() {
        title = user.username ?? LocalizedString("profile.default-title")
    }
    
    private func sendPrivateMessage() {
        let compose = MessageComposeViewController(recipient: user)
        present(compose.enclosingNavigationController, animated: true)
    }
    
    private func showActionsForHomepage(_ url: URL, from frame: CGRect) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
        present(activity, animated: true)
        let popover = activity.popoverPresentationController
        popover?.sourceRect = frame
        popover?.sourceView = renderView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(renderView)
        renderView.translatesAutoresizingMaskIntoConstraints = true
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderProfile()
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
        
        if !didFetchProfile {
            didFetchProfile = true
            
            let userID = user.userID, username = user.username
            ForumsClient.shared.profileUser(id: userID, username: username)
                .done { [weak self] profile in
                    guard let sself = self else { return }
                    sself.user = profile.user
                    sself.renderProfile()
                }
                .catch { error in
                    Log.e("error fetching user profile for \(username ?? "") (ID \(userID)): \(error)")
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
                return try MustacheTemplate.render(.profile, value: RenderModel(profile))
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
}

private struct SendPrivateMessage: RenderViewMessage {
    static let messageName = "sendPrivateMessage"
    
    init?(_ message: WKScriptMessage) {
        assert(message.name == SendPrivateMessage.messageName)
    }
}

private struct ShowHomepageActions: RenderViewMessage {
    static let messageName = "showHomepageActions"
    
    /// The frame of the homepage row, in the render view's scroll view's coordinate system.
    let frame: CGRect
    
    /// Whatever's specified as the homepage. May not be parseable as a URL.
    let urlString: String
    
    init?(_ message: WKScriptMessage) {
        assert(message.name == ShowHomepageActions.messageName)
        
        guard
            let body = message.body as? [String: Any],
            let frame = CGRect(renderViewMessage: body["frame"] as? [String: Double]),
            let urlString = body["url"] as? String
            else { return nil }
        
        self.frame = frame
        self.urlString = urlString
    }
}

extension ProfileViewController: RenderViewDelegate {
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
            UIApplication.shared.openURL(url)
        }
    }
}


private struct RenderModel: MustacheBoxable {
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
    let username: String?
    let yahooName: String?
    
    init(_ profile: Profile) {
        let privateMessagesWork = profile.user.canReceivePrivateMessages && AwfulSettings.shared().canSendPrivateMessages
        
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
        css = {
            let url = Bundle(for: ProfileViewController.self).url(forResource: "profile.css", withExtension: nil)!
            return try! String(contentsOf: url, encoding: .utf8)
        }()
        dark = AwfulSettings.shared().darkTheme
        gender = profile.gender ?? LocalizedString("profile.default-gender")
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
        username = profile.user.username
        yahooName = profile.yahooName
    }
    
    var mustacheBox: MustacheBox {
        return Box([
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
            "username": username as Any,
            "yahooName": yahooName as Any])
    }
}
