//  ThreadPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class ThreadPreviewViewController: PostPreviewViewController {
    private let forum: Forum
    private let subject: String
    private let threadTag: ThreadTag
    private let secondaryThreadTag: ThreadTag?
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.parent = self.forum.managedObjectContext
        return moc
    }()
    private weak var networkOperation: Cancellable?
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    private(set) var formData: ForumsClient.PostNewThreadFormData?
    private lazy var threadCell = ThreadListCell()
    
    init(forum: Forum, subject: String, threadTag: ThreadTag, secondaryThreadTag: ThreadTag?, BBcode: NSAttributedString) {
        self.forum = forum
        self.subject = subject
        self.threadTag = threadTag
        self.secondaryThreadTag = secondaryThreadTag
        super.init(BBcode: BBcode)
        
        title = "Thread Preview"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        threadCell.autoresizingMask = .flexibleWidth
        webView.scrollView.addSubview(threadCell)
    }

    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        repositionCell()
    }
    
    override func fetchPreviewIfNecessary() {
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
    
    override func renderPreview() {
        super.renderPreview()
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
