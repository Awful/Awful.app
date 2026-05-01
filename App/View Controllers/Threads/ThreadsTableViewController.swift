//  ThreadsTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import os
import ScrollViewDelegateMultiplexer
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadsTableViewController")

final class ThreadsTableViewController: CollectionViewController, ComposeTextViewControllerDelegate, ThreadTagPickerViewControllerDelegate {

    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: ThreadListDataSource?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private var filterThreadTag: ThreadTag?
    let forum: Forum
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var latestPage = 0
    private var loadMoreFooter: LoadMoreCollectionFooter?
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.forumThreadsSortedUnread) private var sortUnreadThreadsToTop
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionReusableView>!

    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        return ScrollViewDelegateMultiplexer(scrollView: collectionView)
    }()

    init(forum: Forum) {
        guard let managedObjectContext = forum.managedObjectContext else {
            fatalError("where's the context?")
        }
        self.managedObjectContext = managedObjectContext

        self.forum = forum

        super.init(collectionViewLayout: ThreadsTableViewController.makeLayout(separatorLeadingInset: 0, separatorColor: nil))

        title = forum.name

        navigationItem.rightBarButtonItem = composeBarButtonItem
        updateComposeBarButtonItem()

        headerRegistration = makeHeaderRegistration()
    }

    deinit {
        if isViewLoaded {
            multiplexer.removeDelegate(self)
        }
    }

    override var theme: Theme {
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }

    private static func makeLayout(separatorLeadingInset: CGFloat, separatorColor: UIColor?) -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.headerMode = .supplementary
        config.headerTopPadding = 0
        config.backgroundColor = .clear

        var separatorConfig = UIListSeparatorConfiguration(listAppearance: .plain)
        separatorConfig.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: separatorLeadingInset, bottom: 0, trailing: 0)
        if let separatorColor {
            separatorConfig.color = separatorColor
        }
        config.separatorConfiguration = separatorConfig

        return CollectionViewController.makeListLayout(using: config, pinSectionHeaders: false)
    }

    private func rebuildLayout() {
        let inset = ThreadListCell.separatorLeftInset(showsTagAndRating: showThreadTags, inTableWithWidth: collectionView.bounds.width)
        let layout = ThreadsTableViewController.makeLayout(
            separatorLeadingInset: inset,
            separatorColor: theme[uicolor: "listSeparatorColor"]
        )
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    private func makeHeaderRegistration() -> UICollectionView.SupplementaryRegistration<UICollectionReusableView> {
        UICollectionView.SupplementaryRegistration<UICollectionReusableView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, _ in
            guard let self else { return }
            header.backgroundColor = .clear

            if self.filterButton.superview !== header {
                self.filterButton.removeFromSuperview()
                self.filterButton.translatesAutoresizingMaskIntoConstraints = false
                header.addSubview(self.filterButton)
                NSLayoutConstraint.activate([
                    self.filterButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                    self.filterButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                    self.filterButton.topAnchor.constraint(equalTo: header.topAnchor),
                    self.filterButton.bottomAnchor.constraint(equalTo: header.bottomAnchor),
                ])
            }
        }
    }

    private func makeDataSource() -> ThreadListDataSource {
        var filter: Set<ThreadTag> = []
        if let tag = filterThreadTag {
            filter.insert(tag)
        }
        let dataSource = try! ThreadListDataSource(
            forum: forum,
            sortedByUnread: sortUnreadThreadsToTop,
            showsTagAndRating: showThreadTags,
            threadTagFilter: filter,
            managedObjectContext: managedObjectContext,
            collectionView: collectionView,
            supplementaryViewProvider: { [weak self] cv, kind, indexPath in
                guard let self, kind == UICollectionView.elementKindSectionHeader else { return nil }
                return cv.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            }
        )
        dataSource.delegate = self
        return dataSource
    }

    private func loadPage(_ page: Int) {
        Task {
            do {
                _ = try await ForumsClient.shared.listThreads(in: forum, tagged: filterThreadTag, page: page)

                latestPage = page

                enableLoadMore()

                if filterThreadTag == nil {
                    RefreshMinder.sharedMinder.didRefreshForum(forum)
                } else {
                    RefreshMinder.sharedMinder.didRefreshFilteredForum(forum)
                }

                // Announcements appear in all thread lists.
                RefreshMinder.sharedMinder.didRefresh(.announcements)

                updateComposeBarButtonItem()
            } catch {
                let alert = UIAlertController(networkError: error)
                present(alert, animated: true)
            }

            stopAnimatingPullToRefresh()
            loadMoreFooter?.didFinish()
        }
    }

    private func enableLoadMore() {
        guard loadMoreFooter == nil else { return }

        loadMoreFooter = LoadMoreCollectionFooter(collectionView: collectionView, multiplexer: multiplexer, loadMore: { [weak self] _ in
            guard let self = self else { return }
            self.loadPage(self.latestPage + 1)
        })
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        multiplexer.addDelegate(self)

        dataSource = makeDataSource()
        rebuildLayout()

        pullToRefreshBlock = { [weak self] in self?.refresh() }

        $handoffEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if visible {
                    prepareUserActivity()
                }
            }
            .store(in: &cancellables)

        Publishers.Merge(
            $showThreadTags.dropFirst(),
            $sortUnreadThreadsToTop.dropFirst()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            guard let self else { return }
            dataSource = makeDataSource()
            rebuildLayout()
        }
        .store(in: &cancellables)
    }

    override func themeDidChange() {
        if isViewLoaded {
            rebuildLayout()
        }

        super.themeDidChange()

        loadMoreFooter?.themeDidChange()

        updateFilterButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if collectionView.numberOfSections > 0, collectionView.numberOfItems(inSection: 0) > 0 {
            enableLoadMore()
            updateFilterButton()
        }

        prepareUserActivity()

        let isTimeToRefresh: Bool
        if filterThreadTag == nil {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshForum(forum)
        } else {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshFilteredForum(forum)
        }
        if isTimeToRefresh || collectionView.numberOfSections == 0 || collectionView.numberOfItems(inSection: 0) == 0 {
            refresh()
        }
    }

    // MARK: Actions

    private func refresh() {
        startAnimatingPullToRefresh()

        loadPage(1)
    }

    // MARK: Composition

    private lazy var composeBarButtonItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(ThreadsTableViewController.didTapCompose))
        item.accessibilityLabel = "New thread"
        return item
        }()

    private lazy var threadComposeViewController: ThreadComposeViewController! = { [unowned self] in
        let composeViewController = ThreadComposeViewController(forum: self.forum)
        composeViewController.delegate = self
        return composeViewController
        }()

    private func updateComposeBarButtonItem() {
        composeBarButtonItem.isEnabled = forum.canPost && forum.lastRefresh != nil
    }

    @objc func didTapCompose() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        present(threadComposeViewController.enclosingNavigationController, animated: true, completion: nil)
    }

    // MARK: ComposeTextViewControllerDelegate

    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true) {
            if let thread = self.threadComposeViewController.thread , success {
                let postsPage = PostsPageViewController(thread: thread)
                postsPage.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
                self.showDetailViewController(postsPage, sender: self)
            }

            if !shouldKeepDraft {
                self.threadComposeViewController = nil
            }
        }
    }

    // MARK: Filtering by tag

    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.bounds.size.height = button.intrinsicContentSize.height + 8
        button.addTarget(self, action: #selector(didTapFilterButton), for: .primaryActionTriggered)
        return button
    }()

    private lazy var threadTagPicker: ThreadTagPickerViewController = {
        let imageNames = self.forum.threadTags.array
            .filter { ($0 as! ThreadTag).imageName != nil }
            .map { ($0 as! ThreadTag).imageName! }
        let picker = ThreadTagPickerViewController(firstTag: .noFilter, imageNames: imageNames, secondaryImageNames: [])
        picker.delegate = self
        picker.title = LocalizedString("thread-list.filter.picker-title")
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        return picker
    }()

    @objc private func didTapFilterButton(_ sender: UIButton) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        threadTagPicker.selectImageName(filterThreadTag?.imageName)
        threadTagPicker.present(from: self, sourceView: sender)
    }

    private func updateFilterButton() {
        let title = LocalizedString(filterThreadTag == nil ? "thread-list.filter-button.no-filter" : "thread-list.filter-button.change-filter")
        filterButton.setTitle(title, for: .normal)
        filterButton.titleLabel?.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: -2.5, weight: .medium)
        filterButton.tintColor = theme["tintColor"]
    }

    // MARK: ThreadTagPickerViewControllerDelegate

    func didSelectImageName(
        _ imageName: String?,
        in picker: ThreadTagPickerViewController
    ) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if let imageName = imageName {
            filterThreadTag = forum.threadTags.array
                .compactMap { $0 as? ThreadTag }
                .first { $0.imageName == imageName }
        } else {
            filterThreadTag = nil
        }

        RefreshMinder.sharedMinder.forgetForum(forum)
        updateFilterButton()

        dataSource = makeDataSource()
        rebuildLayout()

        picker.dismiss()
    }

    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
        // nop
    }

    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        // nop
    }

    // MARK: Handoff

    private func prepareUserActivity() {
        guard handoffEnabled else {
            userActivity = nil
            return
        }

        userActivity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        userActivity?.needsSave = true
    }

    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .forum(id: forum.forumID)
        activity.title = forum.name

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ThreadsTableViewController: ThreadListDataSourceDelegate {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme {
        return theme
    }
}

extension ThreadsTableViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .forum(id: forum.forumID)
    }
}

// MARK: UICollectionViewDelegate
extension ThreadsTableViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let thread = dataSource!.thread(at: indexPath)
        let postsViewController = PostsPageViewController(thread: thread)
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        return .makeFromThreadList(
            for: dataSource!.thread(at: indexPath),
               presenter: self
        )
    }
}
