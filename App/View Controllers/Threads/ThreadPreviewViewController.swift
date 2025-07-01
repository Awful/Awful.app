//  ThreadPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import CoreData
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadPreviewViewController")

/// Renders the original post-to-be of a new thread.
final class ThreadPreviewViewController: ViewController {
    
    private let bbcode: NSAttributedString
    private var didRender = false
    private(set) var formData: ForumsClient.PostNewThreadFormData?
    private let forum: Forum
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private var loadingView: LoadingView?
    private var networkOperation: Task<Void, Error>?
    private var post: PostRenderModel?
    private var postHTML: Swift.Result<HTMLAndForm, Error>?
    private let secondaryThreadTag: ThreadTag?
    private let subject: String
    var submitBlock: (() -> Void)?
    private var thread: ThreadListCell.ViewModel?
    private lazy var threadCell = ThreadListCell()
    private let threadTag: ThreadTag
    private var webViewDidLoadOnce = false
    
    private typealias HTMLAndForm = (previewHTML: String, formData: ForumsClient.PostNewThreadFormData)
    
    private lazy var postButtonItem = UIBarButtonItem(primaryAction: UIAction(
        title: LocalizedString("compose.thread-preview.submit-button"),
        handler: { [unowned self] action in
            (action.sender as? UIBarButtonItem)?.isEnabled = false
            self.submitBlock?()
        }
    ))

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
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }
    
    // MARK: Rendering preview
    
    func fetchPreviewIfNecessary() {
        if case .success = postHTML { return }
        guard networkOperation == nil else { return }

        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(bbcode)
        let previewTask = Task {
            try await ForumsClient.shared.previewOriginalPostForThread(in: forum, bbcode: interpolatedBBcode)
        }
        networkOperation = Task { [weak self] in
            do {
                let (previewHTML, formData) = try await previewTask.value

                guard let self,
                      let userKey = FoilDefaultStorageOptional(Settings.userID).wrappedValue.map({ UserKey(userID: $0, username: FoilDefaultStorageOptional(Settings.username).wrappedValue) }),
                      let context = self.managedObjectContext
                else { throw MissingAuthorError() }
                
                let author = User.objectForKey(objectKey: userKey, in: context)

                postHTML = .success((previewHTML, formData))

                self.post = PostRenderModel(author: author, isOP: true, postDate: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short), postHTML: previewHTML)
                self.formData = formData
                self.renderPreview()
            } catch {
                if let self {
                    postHTML = .failure(error)
                    present(UIAlertController(networkError: error), animated: true)
                }
            }
            self?.networkOperation = nil
        }
    }
    
    struct MissingAuthorError: LocalizedError {
        var localizedDescription: String {
            return LocalizedString("compose.post-preview.missing-author-error")
        }
    }
    
    func renderPreview() {
        webViewDidLoadOnce = false
        
        fetchPreviewIfNecessary()
        
        guard let post = post else { return }
        
        let context: [String: Any] = [
            "stylesheet": theme[string: "postsViewCSS"] ?? "",
            "post": post.context]
        do {
            let rendering = try StencilEnvironment.shared.renderTemplate(.postPreview, context: context)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            logger.error("failed to render thread preview: \(error)")
            
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
                .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], weight: .regular),
                .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!]),
            pageIconColor: theme["listSecondaryTextColor"]!,
            postInfo: {
                let text = String(format: LocalizedString("compose.thread-preview.posting-in"), forum.name ?? "")
                return NSAttributedString(string: text, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], weight: .regular),
                    .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!])
            }(),
            ratingImage: nil,
            secondaryTagImageName: secondaryThreadTag?.imageName,
            selectedBackgroundColor: theme["listBackgroundColor"]!,
            stickyImage: nil,
            tagImage: .image(name: threadTag.imageName, placeholder: .thread(in: forum)),
            title: {
                var subject = self.subject
                subject.collapseWhitespace()
                return NSAttributedString(string: subject, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], weight: .regular),
                    .foregroundColor: theme[uicolor: "listTextColor"]!])
            }(),
            unreadCount: NSAttributedString())
        
        repositionCell()
    }
    
    private func repositionCell() {
        let cellHeight = ThreadListCell.heightForViewModel(threadCell.viewModel, inTableWithWidth: view.bounds.width)
        threadCell.frame = CGRect(x: 0, y: -cellHeight, width: view.bounds.width, height: cellHeight)

        let topInset = view.safeAreaLayoutGuide.layoutFrame.minY
        renderView.scrollView.contentInset.top = topInset + cellHeight
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
        
        if didRender, let css = theme[string: "postsViewCSS"] {
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
        let description = "\(message)"
        logger.warning("received unexpected message: \(description)")
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
