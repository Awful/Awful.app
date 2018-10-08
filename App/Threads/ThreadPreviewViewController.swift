//  ThreadPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

private let Log = Logger.get()

/// Renders the original post-to-be of a new thread.
final class ThreadPreviewViewController: ViewController {
    private let BBcode: NSAttributedString
    private var fakePost: Post?
    private(set) var formData: ForumsClient.PostNewThreadFormData?
    private let forum: Forum
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var loadingView: LoadingView?
    private weak var networkOperation: Cancellable?
    private let secondaryThreadTag: ThreadTag?
    private let subject: String
    var submitBlock: (() -> Void)?
    private lazy var threadCell = ThreadListCell()
    private let threadTag: ThreadTag
    private var webViewDidLoadOnce = false
    
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.parent = self.forum.managedObjectContext
        return moc
    }()
    
    private lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: "Post", style: .plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.isEnabled = false
            self?.submitBlock?()
        }
        return buttonItem
    }()
    
    init(forum: Forum, subject: String, threadTag: ThreadTag, secondaryThreadTag: ThreadTag?, BBcode: NSAttributedString) {
        self.BBcode = BBcode
        self.forum = forum
        self.secondaryThreadTag = secondaryThreadTag
        self.subject = subject
        self.threadTag = threadTag
        
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
        
        title = "Thread Preview"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let webView = UIWebView.nativeFeelingWebView()
        webView.delegate = self
        view = webView
    }
    
    private var webView: UIWebView {
        return view as! UIWebView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadingView = LoadingView.loadingViewWithTheme(theme)

        threadCell.autoresizingMask = .flexibleWidth
        webView.scrollView.addSubview(threadCell)
    }

    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        renderPreview()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        repositionCell()
    }
    
    func fetchPreviewIfNecessary() {
        guard fakePost == nil && networkOperation == nil else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(BBcode)
        let (html, cancellable) = ForumsClient.shared.previewOriginalPostForThread(in: forum, bbcode: interpolatedBBcode)
        networkOperation = cancellable
        html.done { [weak self] previewAndForm in
            guard let sself = self else { return }

            sself.networkOperation = nil
            let context = sself.managedObjectContext

            let threadKey = ThreadKey(threadID: "fake")
            let fakeThread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: context) as! AwfulThread
            let userKey = UserKey(userID: AwfulSettings.shared().userID, username: AwfulSettings.shared().username)
            fakeThread.author = User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User
            let postKey = PostKey(postID: "sofake")
            sself.fakePost = Post.objectForKey(objectKey: postKey, inManagedObjectContext: context) as? Post
            sself.fakePost?.thread = fakeThread
            sself.fakePost?.author = fakeThread.author
            sself.fakePost?.innerHTML = previewAndForm.previewHTML
            sself.fakePost?.postDate = Date()
            sself.formData = previewAndForm.formData
            sself.renderPreview()
            }
            .catch { [weak self] error in
                self?.present(UIAlertController(networkError: error), animated: true)
        }
    }
    
    func renderPreview() {
        webViewDidLoadOnce = false
        
        fetchPreviewIfNecessary()
        
        guard let fakePost = fakePost else { return }
        
        var context: [String: Any] = [
            "stylesheet": (theme["postsViewCSS"] as String? ?? ""),
            "post": PostViewModel(fakePost)]
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
        
        configureCell()
    }
    
    private func configureCell() {
        threadCell.viewModel = ThreadListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            pageCount: NSAttributedString(string: "1", attributes: [
                .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"]),
                .foregroundColor: (theme["listSecondaryTextColor"] as UIColor?)!]),
            pageIconColor: theme["listSecondaryTextColor"]!,
            postInfo: {
                let text = String(format: LocalizedString("compose.thread-preview.posting-in"), forum.name ?? "")
                return NSAttributedString(string: text, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"]),
                    .foregroundColor: (theme["listSecondaryTextColor"] as UIColor?)!])
            }(),
            ratingImage: nil,
            secondaryTagImage: {
                let imageName = secondaryThreadTag?.imageName
                guard imageName != threadTag.imageName else {
                    return nil
                }

                return imageName.flatMap { ThreadTagLoader.sharedLoader.imageNamed($0) }
            }(),
            selectedBackgroundColor: theme["listBackgroundColor"]!,
            stickyImage: nil,
            tagImage: {
                return threadTag.imageName.flatMap { ThreadTagLoader.sharedLoader.imageNamed($0) }
                    ?? ThreadTagLoader.emptyThreadTagImage
            }(),
            title: NSAttributedString(string: (subject as NSString).stringByCollapsingWhitespace, attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"]),
                .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
            unreadCount: NSAttributedString())
        
        repositionCell()
    }
    
    private func repositionCell() {
        let cellHeight = ThreadListCell.heightForViewModel(threadCell.viewModel, inTableWithWidth: view.bounds.width)
        threadCell.frame = CGRect(x: 0, y: -cellHeight, width: view.bounds.width, height: cellHeight)
        webView.scrollView.contentInset.top = topLayoutGuide.length + cellHeight
    }
}

extension ThreadPreviewViewController: UIWebViewDelegate {
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
