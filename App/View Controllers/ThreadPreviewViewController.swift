//  ThreadPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import PromiseKit

private let Log = Logger.get()

/// Renders the original post-to-be of a new thread.
final class ThreadPreviewViewController: ViewController {
    
    private let bbcode: NSAttributedString
    private var didRender = false
    private(set) var formData: ForumsClient.PostNewThreadFormData?
    private let forum: Forum
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var loadingView: LoadingView?
    private weak var networkOperation: Cancellable?
    private var post: PostViewModel?
    private var postHTML: Promise<HTMLAndForm>?
    private let secondaryThreadTag: ThreadTag?
    private let subject: String
    var submitBlock: (() -> Void)?
    private var thread: ThreadListCell.ViewModel?
    private lazy var threadCell = ThreadListCell()
    private let threadTag: ThreadTag
    private var webViewDidLoadOnce = false
    
    private typealias HTMLAndForm = (previewHTML: String, formData: ForumsClient.PostNewThreadFormData)
    
    private lazy var postButtonItem: UIBarButtonItem = {
        let buttonItem = UIBarButtonItem(title: LocalizedString("compose.thread-preview.submit-button"), style: .plain, target: nil, action: nil)
        buttonItem.actionBlock = { [weak self] item in
            item.isEnabled = false
            self?.submitBlock?()
        }
        return buttonItem
    }()
    
    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()
    
    init(forum: Forum, subject: String, threadTag: ThreadTag, secondaryThreadTag: ThreadTag?, bbcode: NSAttributedString) {
        self.bbcode = bbcode
        self.forum = forum
        self.secondaryThreadTag = secondaryThreadTag
        self.subject = subject
        self.threadTag = threadTag
        
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.rightBarButtonItem = postButtonItem
        
        title = LocalizedString("compose.thread-preview.title")
    }
    
    private var managedObjectContext: NSManagedObjectContext? {
        return forum.managedObjectContext
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }
    
    // MARK: Rendering preview
    
    func fetchPreviewIfNecessary() {
        guard postHTML == nil || postHTML?.isRejected == true else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(bbcode)
        let (html, cancellable) = ForumsClient.shared.previewOriginalPostForThread(in: forum, bbcode: interpolatedBBcode)
        networkOperation = cancellable
        
        postHTML = html
        html
            .done { [weak self] previewAndForm in
                guard let self = self else { return }
                
                self.networkOperation = nil
                
                guard
                    let userKey = AwfulSettings.shared().userID.map({ UserKey(userID: $0, username: AwfulSettings.shared().username) }),
                    let context = self.managedObjectContext,
                    let author = User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User
                    else { throw MissingAuthorError() }
                
                self.post = PostViewModel(author: author, isOP: true, postDate: Date(), postHTML: previewAndForm.previewHTML)
                self.formData = previewAndForm.formData
                self.renderPreview()
            }
            .catch { [weak self] error in
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
        
        let context: [String: Any] = [
            "stylesheet": (theme["postsViewCSS"] as String? ?? ""),
            "post": post]
        do {
            let rendering = try MustacheTemplate.render(.postPreview, value: context)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            Log.e("failed to render thread preview: \(error)")
            
            // TODO: show error nicer
            renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
        }
        
        configureCell()
        
        didRender = true
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
            title: {
                var subject = self.subject
                subject.collapseWhitespace()
                return NSAttributedString(string: subject, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"]),
                    .foregroundColor: (theme["listTextColor"] as UIColor?)!])
            }(),
            unreadCount: NSAttributedString())
        
        repositionCell()
    }
    
    private func repositionCell() {
        let cellHeight = ThreadListCell.heightForViewModel(threadCell.viewModel, inTableWithWidth: view.bounds.width)
        threadCell.frame = CGRect(x: 0, y: -cellHeight, width: view.bounds.width, height: cellHeight)
        renderView.scrollView.contentInset.top = topLayoutGuide.length + cellHeight
    }
    
    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(renderView, at: 0)
        
        threadCell.autoresizingMask = .flexibleWidth
        renderView.scrollView.addSubview(threadCell)
        
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        repositionCell()
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ThreadPreviewViewController: RenderViewDelegate {
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
            UIApplication.shared.openURL(url)
        }
    }
    
    func renderProcessDidTerminate(in view: RenderView) {
        renderPreview()
    }
}
