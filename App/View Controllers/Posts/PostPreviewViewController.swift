//  PostPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

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
    private var networkOperation: Task<Void, Never>?
    private var post: PostRenderModel?
    private var postHTML: Swift.Result<String, Error>?
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
        // Avoid warning in Xcode 14 beta 1 "cannot access property with a non-sendable type from a non-isolated deinit"
        // UIViewController actually does guarantee deinit on the main queue, but the Swift compiler doesn't know that.
        // (Also, it seems like an oversight that wrapping the access in an immediately-executed closure avoids the warning, so be prepared for more warnings here.)
        { networkOperation?.cancel() }()
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
            else { return Theme.defaultTheme() }
        return Theme.currentTheme(for: forum)
    }
    
    // MARK: Rendering the preview
    
    func fetchPreviewIfNecessary() {
        if case .success = postHTML { return }
        guard networkOperation == nil else { return }

        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(bbcode)

        let fetchPreview: () async throws -> String
        if let editingPost {
            fetchPreview = { try await ForumsClient.shared.previewEdit(to: editingPost, bbcode: interpolatedBBcode) }
        } else if let thread {
            fetchPreview = { try await ForumsClient.shared.previewReply(to: thread, bbcode: interpolatedBBcode) }
        } else {
            return Log.e("nothing to do??")
        }
        networkOperation = Task { [weak self] in
            do {
                let html = try await fetchPreview()

                guard let self,
                      let context = managedObjectContext
                else { return }

                try Task.checkCancellation()

                var loggedInUser: User? {
                    guard let userID = UserDefaults.standard.loggedInUserID else {
                        return nil
                    }
                    let userKey = UserKey(userID: userID, username: UserDefaults.standard.loggedInUsername)
                    return User.objectForKey(objectKey: userKey, in: context)
                }
                
                guard let author = editingPost?.author ?? loggedInUser else {
                    throw MissingAuthorError()
                }
                
                let postDate = editingPost?.postDateRaw ?? DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                
                let isOP = editingPost?.author == author
                
                post = PostRenderModel(author: author, isOP: isOP, postDate: postDate, postHTML: html)

                renderPreview()
            } catch {
                Log.e("could not preview post: \(error)")

                self?.present(UIAlertController(networkError: error), animated: true)
            }
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
            "post": post.context,
            "stylesheet": theme[string: "postsViewCSS"] ?? ""]
        do {
            let rendering = try StencilEnvironment.shared.renderTemplate(.postPreview, context: context)
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
        
        let loadingView = LoadingView.loadingViewWithTheme(theme)
        self.loadingView = loadingView
        view.addSubview(loadingView)
        
        renderPreview()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        if didRender, let css = theme[string: "postsViewCSS"] {
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
    func didFinishRenderingHTML(in view: RenderView) {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
    
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        Log.w("received unexpected message: \(message)")
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
        renderPreview()
    }
}
