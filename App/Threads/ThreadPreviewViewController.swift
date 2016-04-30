//  ThreadPreviewViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class ThreadPreviewViewController: PostPreviewViewController {
    private let forum: Forum
    private let subject: String
    private let threadTag: ThreadTag
    private let secondaryThreadTag: ThreadTag?
    private var threadCell: ThreadCell!
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.parentContext = self.forum.managedObjectContext
        return moc
    }()
    private var networkOperation: NSOperation?
    private var imageInterpolator: SelfHostingAttachmentInterpolator?
    
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
    
    override func loadView() {
        super.loadView()
        
        threadCell = NSBundle(forClass: ThreadPreviewViewController.self).loadNibNamed("ThreadCell", owner: nil, options: nil)[0] as! ThreadCell
        threadCell.autoresizingMask = .FlexibleWidth
        webView.scrollView.addSubview(threadCell)
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum)
    }
    
    override func fetchPreviewIfNecessary() {
        guard fakePost == nil && networkOperation == nil else { return }
        
        let imageInterpolator = SelfHostingAttachmentInterpolator()
        self.imageInterpolator = imageInterpolator
        let interpolatedBBcode = imageInterpolator.interpolateImagesInString(BBcode)
        networkOperation = AwfulForumsClient.sharedClient().previewOriginalPostForThreadInForum(forum, withBBcode: interpolatedBBcode, andThen: { [weak self] (error, postHTML) in
            if let error = error {
                self?.presentViewController(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
                return
            }
            
            self?.networkOperation = nil
            guard let context = self?.managedObjectContext else { return }
            
            let threadKey = ThreadKey(threadID: "fake")
            let fakeThread = Thread.objectForKey(threadKey, inManagedObjectContext: context) as! Thread
            let userKey = UserKey(userID: AwfulSettings.sharedSettings().userID, username: AwfulSettings.sharedSettings().username)
            fakeThread.author = User.objectForKey(userKey, inManagedObjectContext: context) as? User
            let postKey = PostKey(postID: "sofake")
            self?.fakePost = Post.objectForKey(postKey, inManagedObjectContext: context) as? Post
            self?.fakePost?.thread = fakeThread
            self?.fakePost?.author = fakeThread.author
            self?.fakePost?.innerHTML = postHTML
            self?.fakePost?.postDate = NSDate()
            self?.renderPreview()
        })
    }
    
    override func renderPreview() {
        super.renderPreview()
        configureCell()
    }
    
    private func configureCell() {
        if AwfulSettings.sharedSettings().showThreadTags {
            /**
                It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
 
                Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use the empty thread tag for anyone lame enough to pick the same tag twice.
             */
            if threadTag != secondaryThreadTag,
                let imageName = threadTag.imageName where !imageName.isEmpty
            {
                threadCell.tagImageView.image = ThreadTagLoader.imageNamed(imageName)
            } else {
                threadCell.tagImageView.image = ThreadTagLoader.emptyThreadTagImage
            }
            
            if let imageName = secondaryThreadTag?.imageName where !imageName.isEmpty {
                threadCell.secondaryTagImageView.image = ThreadTagLoader.imageNamed(imageName)
            } else {
                threadCell.secondaryTagImageView.image = nil
            }
        } else {
            threadCell.showsTag = false
        }
        
        threadCell.titleLabel.text = (subject as NSString).stringByCollapsingWhitespace
        threadCell.tagAndRatingContainerView.alpha = 1
        threadCell.titleLabel.enabled = true
        threadCell.numberOfPagesLabel.text = "1"
        threadCell.unreadRepliesLabel.text = ""
        threadCell.killedByLabel.text = "Posting in \(forum.name ?? "")"
        threadCell.showsRating = false
        
        threadCell.backgroundColor = theme["listBackgroundColor"]
        threadCell.titleLabel.textColor = theme["listTextColor"]
        threadCell.numberOfPagesLabel.textColor = theme["listSecondaryTextColor"]
        threadCell.killedByLabel.textColor = theme["listSecondaryTextColor"]
        threadCell.tintColor = theme["listSecondaryTextColor"]
        threadCell.fontNameForLabels = theme["listFontName"]
        
        repositionCell()
    }
    
    private func repositionCell() {
        threadCell.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 10000)
        threadCell.setNeedsLayout()
        threadCell.layoutIfNeeded()
        
        threadCell.titleLabel.preferredMaxLayoutWidth = threadCell.titleLabel.bounds.width
        let height = threadCell.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        threadCell.frame = CGRect(x: 0, y: -height, width: view.bounds.width, height: height)
        
        webView.scrollView.contentInset.top = topLayoutGuide.length + threadCell.bounds.height
    }
}
