//  PostPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import GRMustache

/// Previews a post (new or edited).
class PostPreviewViewController: AwfulViewController {
    let editingPost: Post?
    let thread: Thread?
    let BBcode: NSAttributedString
    var submitBlock: (() -> Void)?
    private var loadingView: LoadingView?
    var fakePost: Post?
    private var networkOperation: NSOperation?
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var webViewDidLoadOnce = false
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.parentContext = self.editingPost?.managedObjectContext ?? self.thread?.managedObjectContext
        return context
    }()
    
    /// Preview editing a post.
    convenience init(post: Post, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, post: post)
        
        title = "Save"
    }
    
    /// Preview a new post.
    convenience init(thread: Thread, BBcode: NSAttributedString) {
        self.init(BBcode: BBcode, thread: thread)
        
        title = "Post Preview"
    }
    
    init(BBcode: NSAttributedString, post: Post? = nil, thread: Thread? = nil) {
        self.BBcode = BBcode
        editingPost = post
        self.thread = thread
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: "Post", style: .Plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.enabled = false
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
        let callback: (NSError?, String?) -> Void = { [weak self] (error, postHTML) in
            if let error = error {
                self?.presentViewController(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
                return
            }
            
            guard let
                postHTML = postHTML,
                context = self?.managedObjectContext
                else { return }
            let postKey = PostKey(postID: "fake")
            self?.fakePost = Post.objectForKey(postKey, inManagedObjectContext: context) as? Post
            let userKey = UserKey(userID: AwfulSettings.sharedSettings().userID, username: AwfulSettings.sharedSettings().username)
            guard let loggedInUser = User.objectForKey(userKey, inManagedObjectContext: context) as? User else { return }
            
            if let editingPost = self?.editingPost {
                // Create a copy of the post we're editing. We'll later change the properties we care about previewing.
                for property in editingPost.entity.properties {
                    if let attribute = property as? NSAttributeDescription {
                        let actualValue = editingPost.valueForKey(attribute.name)
                        self?.fakePost?.setValue(actualValue, forKey: attribute.name)
                    } else if let
                        relationship = property as? NSRelationshipDescription,
                        actualValue = editingPost.valueForKey(relationship.name) as? NSManagedObject
                    {
                        self?.fakePost?.setValue(context.objectWithID(actualValue.objectID), forKey: relationship.name)
                    }
                }
            } else {
                self?.fakePost?.postDate = NSDate()
                self?.fakePost?.author = loggedInUser
            }
            
            self?.fakePost?.innerHTML = postHTML
            self?.renderPreview()
        }
        
        if let editingPost = editingPost {
            networkOperation = AwfulForumsClient.sharedClient().previewEditToPost(editingPost, withBBcode: interpolatedBBcode, andThen: callback)
        } else if let thread = thread {
            networkOperation = AwfulForumsClient.sharedClient().previewReplyToThread(thread, withBBcode: interpolatedBBcode, andThen: callback)
        } else {
            print("\(#function) Nothing to do??")
        }
    }
    
    func renderPreview() {
        webViewDidLoadOnce = false
        
        fetchPreviewIfNecessary()
        
        guard let fakePost = fakePost else { return }
        var context: [String: AnyObject] = [
            "userInterfaceIdiom": UIDevice.currentDevice().userInterfaceIdiom == .Pad ? "ipad" : "iphone",
            "version": NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String,
            "stylesheet": theme["postsViewCSS"] as String? ?? "",
            "post": PostViewModel(post: fakePost),
        ]
        do {
            var error: NSError?
            if let script = LoadJavaScriptResources(["zepto.min.js", "common.js"], &error) {
                context["script"] = script
            } else if let error = error {
                throw error
            }
        } catch {
            print("\(#function) error loading: \(error)")
        }
        if AwfulSettings.sharedSettings().fontScale != 100 {
            context["fontScalePercentage"] = AwfulSettings.sharedSettings().fontScale
        }
        
        do {
            let html = try GRMustacheTemplate.renderObject(context, fromResource: "PostPreview", bundle: nil)
            webView.loadHTMLString(html, baseURL: AwfulForumsClient.sharedClient().baseURL)
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
            forum = thread.forum
            else { return Theme.defaultTheme }
        return Theme.currentThemeForForum(forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderPreview()
    }
}

extension PostPreviewViewController: UIWebViewDelegate {
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        var navigationType = navigationType
        
        // YouTube embeds can take over the frame when someone taps the video title. Here we try to detect that and treat it as if a link was tapped.
        if navigationType != .LinkClicked && request.URL?.host?.lowercaseString.hasSuffix("www.youtube.com") == true && request.URL?.path?.lowercaseString.hasPrefix("/watch") == true {
            navigationType = .LinkClicked
        }
        
        return navigationType != .LinkClicked
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        guard !webViewDidLoadOnce else { return }
        webViewDidLoadOnce = true
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}
