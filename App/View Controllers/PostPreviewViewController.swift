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
    private let editingPost: Post?
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var loadingView: LoadingView?
    private weak var networkOperation: Cancellable?
    private var post: PostViewModel?
    var submitBlock: (() -> Void)?
    private let thread: AwfulThread?
    private var webViewDidLoadOnce = false
    
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
    
    private var webView: UIWebView {
        return view as! UIWebView
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
        webViewDidLoadOnce = false
        
        fetchPreviewIfNecessary()
        
        guard let post = post else { return }

        var context: [String: Any] = [
            "stylesheet": (theme["postsViewCSS"] as String? ?? ""),
            "post": post]
        do {
            var error: NSError?
            if let script = LoadJavaScriptResources(["zepto.min.js", "common.js"], &error) {
                context["script"] = script as AnyObject?
            } else if let error = error {
                throw error
            }
        } catch {
            Log.e("error loading JavaScripts: \(error)")
        }

        let html: String
        do {
            html = try MustacheTemplate.render(.postPreview, value: context)
        } catch {
            Log.e("failed to render post preview HTML: \(error)")
            html = ""
        }
        webView.loadHTMLString(html, baseURL: ForumsClient.shared.baseURL)
        
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
    
    // MARK: View lifecycle
    
    override func loadView() {
        let webView = UIWebView.nativeFeelingWebView()
        webView.delegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadingView = LoadingView.loadingViewWithTheme(theme)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderPreview()
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PostPreviewViewController: UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        var navigationType = navigationType
        
        // YouTube embeds can take over the frame when someone taps the video title. Here we try to detect that and treat it as if a link was tapped.
        if navigationType != .linkClicked && (request as NSURLRequest).url?.host?.lowercased().hasSuffix("www.youtube.com") == true && (request as NSURLRequest).url?.path.lowercased().hasPrefix("/watch") == true {
            navigationType = .linkClicked
        }
        
        return navigationType != .linkClicked
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        guard !webViewDidLoadOnce else { return }
        webViewDidLoadOnce = true
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}
