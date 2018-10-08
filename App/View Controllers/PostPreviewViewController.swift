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
    
    /// Preview editing a post.
    convenience init(post: Post, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, post: post)
        
        title = "Save"
    }
    
    /// Preview a new post.
    convenience init(thread: AwfulThread, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, thread: thread)
        
        title = "Post Preview"
    }
    
    init(BBcode: NSAttributedString, post: Post? = nil, thread: AwfulThread? = nil) {
        self.bbcode = BBcode
        editingPost = post
        self.thread = thread
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: "Post", style: .plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.isEnabled = false
            self?.submitBlock?()
        }
        return buttonItem
    }()
    
    private var webView: UIWebView {
        return view as! UIWebView
    }
    
    private var managedObjectContext: NSManagedObjectContext? {
        let forum = editingPost?.thread?.forum ?? thread?.forum
        return forum?.managedObjectContext
    }
    
    func fetchPreviewIfNecessary() {
        guard networkOperation == nil else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(bbcode)
        let callback: (Error?, String?) -> Void = { [weak self] (error, postHTML) in
            if let error = error {
                Log.e("could not preview post: \(error)")
                
                self?.present(UIAlertController(networkError: error), animated: true)
                
                return
            }
            
            let userKey = UserKey(userID: AwfulSettings.shared().userID, username: AwfulSettings.shared().username)
            
            guard
                let postHTML = postHTML,
                let sself = self,
                let context = sself.managedObjectContext,
                let author = sself.editingPost?.author ?? (User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User) else
            {
                Log.e("missing either the post HTML or the post author")
                return
            }
            
            sself.post = PostViewModel(
                author: author,
                postDate: sself.editingPost?.postDate ?? Date(),
                postHTML: postHTML)
            
            sself.renderPreview()
        }

        let promise: Promise<String>
        let cancellable: Cancellable
        if let editingPost = editingPost {
            (promise: promise, cancellable: cancellable) = ForumsClient.shared.previewEdit(to: editingPost, bbcode: interpolatedBBcode)
        } else if let thread = thread {
            (promise: promise, cancellable: cancellable) = ForumsClient.shared.previewReply(to: thread, bbcode: interpolatedBBcode)
        } else {
            print("\(#function) Nothing to do??")
            return
        }
        networkOperation = cancellable
        promise
            .done { callback(nil, $0) }
            .catch { callback($0, nil) }
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
    
    override func loadView() {
        let webView = UIWebView.nativeFeelingWebView()
        webView.delegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadingView = LoadingView.loadingViewWithTheme(theme)
    }
    
    override var theme: Theme {
        guard let
            thread = thread ?? editingPost?.thread,
            let forum = thread.forum
            else { return Theme.defaultTheme }
        return Theme.currentThemeForForum(forum: forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderPreview()
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
