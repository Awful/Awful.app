//  PostPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import PromiseKit

private let Log = Logger.get()

/**
 Previews a post (a.k.a. a reply to a thread). May be a new post, may be edited.
 
 Note that some users (e.g. moderators) can edit other users' posts.
 */
final class PostPreviewViewController: ViewController {
    private let bbcode: NSAttributedString
    private var didRender = false
    private let editingPost: Post?
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var loadingView: LoadingView?
    private weak var networkOperation: Cancellable?
    private var post: PostViewModel?
    var submitBlock: (() -> Void)?
    private let thread: AwfulThread?
    
    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()
    
    /// Preview editing an existing post.
    convenience init(post: Post, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, post: post)
        
        title = LocalizedString("compose.post-preview.title-editing")
    }
    
    /// Preview a new post.
    convenience init(thread: AwfulThread, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, thread: thread)
        
        title = LocalizedString("compose.post-preview.title-new")
    }
    
    private init(BBcode: NSAttributedString, post: Post? = nil, thread: AwfulThread? = nil) {
        self.bbcode = BBcode
        editingPost = post
        self.thread = thread
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
    }
    
    deinit {
        networkOperation?.cancel()
    }
    
    private var managedObjectContext: NSManagedObjectContext? {
        let forum = editingPost?.thread?.forum ?? thread?.forum
        return forum?.managedObjectContext
    }
    
    private lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: "Post", style: .plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.isEnabled = false
            self?.submitBlock?()
        }
        return buttonItem
    }()
    
    override var theme: Theme {
        guard
            let thread = thread ?? editingPost?.thread,
            let forum = thread.forum
            else { return Theme.defaultTheme }
        return Theme.currentThemeForForum(forum: forum)
    }
    
    // MARK: Rendering the preview
    
    func fetchPreviewIfNecessary() {
        guard networkOperation == nil else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(bbcode)

        let html: Promise<String>
        let cancellable: Cancellable
        if let editingPost = editingPost {
            (promise: html, cancellable: cancellable) = ForumsClient.shared.previewEdit(to: editingPost, bbcode: interpolatedBBcode)
        } else if let thread = thread {
            (promise: html, cancellable: cancellable) = ForumsClient.shared.previewReply(to: thread, bbcode: interpolatedBBcode)
        } else {
            return Log.e("nothing to do??")
        }
        networkOperation = cancellable
        
        html
            .done { [weak self] html in
                guard let sself = self, let context = sself.managedObjectContext else { return }
                
                var loggedInUser: User? {
                    let settings = AwfulSettings.shared()!
                    let userKey = UserKey(userID: settings.userID, username: settings.username)
                    return User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User
                }
                
                guard let author = sself.editingPost?.author ?? loggedInUser else {
                    throw MissingAuthorError()
                }
                
                let postDate = sself.editingPost?.postDate ?? Date()
                
                sself.post = PostViewModel(author: author, postDate: postDate, postHTML: html)
                
                sself.renderPreview()
            }
            .catch { [weak self] error in
                Log.e("could not preview post: \(error)")
                
                self?.present(UIAlertController(networkError: error), animated: true)
        }
    }
    
    struct MissingAuthorError: Error {
        var localizedDescription: String {
            return LocalizedString("compose.post-preview.missing-author-error")
        }
    }

    func renderPreview() {
        fetchPreviewIfNecessary()
        
        guard let post = post else { return }
        
        let context: [String: Any] = [
            "post": post,
            "stylesheet": (theme["postsViewCSS"] as String? ?? "")]
        do {
            let rendering = try MustacheTemplate.render(.postPreview, value: context)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            Log.e("failed to render post preview: \(error)")
            
            // TODO: show error nicer
            renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
        }
        
        didRender = true
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(renderView, at: 0)
        
        renderView.registerMessage(RenderView.BuiltInMessage.DidRender.self)
        
        let loadingView = LoadingView.loadingViewWithTheme(theme)
        self.loadingView = loadingView
        view.addSubview(loadingView)
        
        renderPreview()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        if didRender, let css = theme["postsViewCSS"] as String? {
            renderView.setThemeStylesheet(css)
        }
        
        loadingView?.tintColor = theme["backgroundColor"]
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PostPreviewViewController: RenderViewDelegate {
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case is RenderView.BuiltInMessage.DidRender:
            loadingView?.removeFromSuperview()
            loadingView = nil
            
        default:
            Log.w("received unexpected message: \(message)")
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
