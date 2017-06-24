//  PostPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import GRMustache
import PromiseKit

/// Previews a post (new or edited).
class PostPreviewViewController: ViewController {
    let editingPost: Post?
    let thread: AwfulThread?
    let BBcode: NSAttributedString
    var submitBlock: (() -> Void)?
    fileprivate var loadingView: LoadingView?
    var fakePost: Post?
    fileprivate weak var networkOperation: Cancellable?
    fileprivate var imageInterpolator: SelfHostingAttachmentInterpolator?
    fileprivate var webViewDidLoadOnce = false
    fileprivate lazy var managedObjectContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = self.editingPost?.managedObjectContext ?? self.thread?.managedObjectContext
        return context
    }()
    
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
        self.BBcode = BBcode
        editingPost = post
        self.thread = thread
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: "Post", style: .plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.isEnabled = false
            self?.submitBlock?()
        }
        return buttonItem
    }()
    
    var webView: UIWebView {
        return view as! UIWebView
    }
    
    func fetchPreviewIfNecessary() {
        guard fakePost == nil && networkOperation == nil else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(BBcode)
        let callback: (Error?, String?) -> Void = { [weak self] (error, postHTML) in
            if let error = error {
                self?.present(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
                return
            }
            
            guard let
                postHTML = postHTML,
                let context = self?.managedObjectContext
                else { return }
            let postKey = PostKey(postID: "fake")
            self?.fakePost = Post.objectForKey(objectKey: postKey, inManagedObjectContext: context) as? Post
            let userKey = UserKey(userID: AwfulSettings.shared().userID, username: AwfulSettings.shared().username)
            guard let loggedInUser = User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User else { return }
            
            if let editingPost = self?.editingPost {
                // Create a copy of the post we're editing. We'll later change the properties we care about previewing.
                for property in editingPost.entity.properties {
                    if let attribute = property as? NSAttributeDescription {
                        let actualValue = editingPost.value(forKey: attribute.name)
                        self?.fakePost?.setValue(actualValue, forKey: attribute.name)
                    } else if let
                        relationship = property as? NSRelationshipDescription,
                        let actualValue = editingPost.value(forKey: relationship.name) as? NSManagedObject
                    {
                        self?.fakePost?.setValue(context.object(with: actualValue.objectID), forKey: relationship.name)
                    }
                }
            } else {
                self?.fakePost?.postDate = Date()
                self?.fakePost?.author = loggedInUser
            }
            
            self?.fakePost?.innerHTML = postHTML
            self?.renderPreview()
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
            .then { callback(nil, $0) }
            .catch { callback($0, nil) }
    }

    func renderPreview() {
        webViewDidLoadOnce = false
        
        fetchPreviewIfNecessary()
        
        guard let fakePost = fakePost else { return }
        var context: [String: AnyObject] = [
            "userInterfaceIdiom": (UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone") as NSString,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String as NSString,
            "stylesheet": (theme["postsViewCSS"] as String? ?? "") as NSString,
            "post": PostViewModel(post: fakePost),
        ]
        do {
            var error: NSError?
            if let script = LoadJavaScriptResources(["zepto.min.js", "common.js"], &error) {
                context["script"] = script as AnyObject?
            } else if let error = error {
                throw error
            }
        } catch {
            print("\(#function) error loading: \(error)")
        }
        if AwfulSettings.shared().fontScale != 100 {
            context["fontScalePercentage"] = AwfulSettings.shared().fontScale as AnyObject?
        }
        
        do {
            let html = try GRMustacheTemplate.renderObject(context, fromResource: "PostPreview", bundle: nil)
            webView.loadHTMLString(html, baseURL: ForumsClient.shared.baseURL)
        } catch {
            print("\(#function) error loading post preview HTML: \(error)")
        }
        
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
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
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
