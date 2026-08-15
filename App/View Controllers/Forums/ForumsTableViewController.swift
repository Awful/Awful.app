//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulGlossary
import AwfulSearch
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import os
import UIKit
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsTableViewController")

final class ForumsTableViewController: CollectionViewController {

    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorage(Settings.hasArchives) private var hasArchives
    private var favoriteForumCountObserver: ManagedObjectCountObserver!
    private var listDataSource: ForumListDataSource!
    let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showUnreadAnnouncementsBadge) private var showUnreadAnnouncementsBadge
    private var unreadAnnouncementCountObserver: ManagedObjectCountObserver!
    private var cellRegistration: UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView>!
    private var archivesBannerRegistration: UICollectionView.SupplementaryRegistration<ForumsArchivesBannerView>!
    /// The live banner view, so its text can be refreshed in place when the timeframe changes without
    /// the layout re-dequeuing it (which it doesn't for an active→active date change).
    private weak var archivesBannerView: ForumsArchivesBannerView?
    /// Whether the layout currently includes the banner, to detect appear/disappear vs. text-only changes.
    private var isArchivesBannerInLayout = false
    /// Layout element kind for the maroon "Archives view" banner shown above every section.
    private static let archivesBannerElementKind = "ForumsArchivesBanner"
    /// The right-bar overflow (⋯) and Search button views on the standard (non–iOS 26 iPad) path, kept so
    /// `updateButtonColors()` can retint them on theme changes — mirroring `BookmarksTableViewController`.
    private var moreButtonView: UIButton?
    private var searchButtonView: UIButton?

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(collectionViewLayout: ForumsTableViewController.makeLayout(separatorLeadingInset: tableSeparatorLeftMargin, separatorColor: nil, showArchivesBanner: ForumsClient.shared.currentArchivesTimeframe != nil, swipeActionsProvider: nil))

        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")

        favoriteForumCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: ForumMetadata.entityName,
            predicate: NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite)),
            didChange: { [weak self] favoriteCount in
                guard let self else { return }
                updateEditingState(favoriteCount: favoriteCount)
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        })
        updateEditingState(favoriteCount: favoriteForumCountObserver.count)

        unreadAnnouncementCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: Announcement.entityName,
            predicate: NSPredicate(format: "%K == NO", #keyPath(Announcement.hasBeenSeen)),
            didChange: { [weak self] unreadCount in
                self?.updateBadgeValue(unreadCount) })

        $showUnreadAnnouncementsBadge
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                updateBadgeValue(unreadAnnouncementCountObserver.count)
            }
            .store(in: &cancellables)

        cellRegistration = makeCellRegistration()
        headerRegistration = makeHeaderRegistration()
        archivesBannerRegistration = makeArchivesBannerRegistration()

        themeDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout(
        separatorLeadingInset: CGFloat,
        separatorColor: UIColor?,
        showArchivesBanner: Bool,
        swipeActionsProvider: ((IndexPath) -> UISwipeActionsConfiguration?)?
    ) -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
        config.headerMode = .supplementary
        config.backgroundColor = .clear

        var separatorConfig = UIListSeparatorConfiguration(listAppearance: .plain)
        separatorConfig.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: separatorLeadingInset, bottom: 0, trailing: 0)
        if let separatorColor {
            separatorConfig.color = separatorColor
        }
        config.separatorConfiguration = separatorConfig

        if let swipeActionsProvider {
            config.trailingSwipeActionsConfigurationProvider = { indexPath in
                swipeActionsProvider(indexPath)
            }
        }

        let layout = CollectionViewController.makeListLayout(using: config)

        // A full-width maroon banner pinned above every section (so it sits above "Favorite Forums")
        // whenever archives mode is active.
        if showArchivesBanner {
            let bannerItem = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(36)),
                elementKind: archivesBannerElementKind,
                alignment: .top)
            // Scrolls away with the list (like the thread-list banner) rather than staying pinned.
            bannerItem.pinToVisibleBounds = false
            let layoutConfig = layout.configuration
            layoutConfig.contentInsetsReference = .none
            layoutConfig.boundarySupplementaryItems = [bannerItem]
            layout.configuration = layoutConfig
        }

        return layout
    }

    private func rebuildLayout() {
        let layout = ForumsTableViewController.makeLayout(
            separatorLeadingInset: tableSeparatorLeftMargin,
            separatorColor: theme[uicolor: "listSeparatorColor"],
            showArchivesBanner: ForumsClient.shared.currentArchivesTimeframe != nil,
            swipeActionsProvider: { [weak self] indexPath in
                self?.swipeActionsConfig(at: indexPath)
            }
        )
        isArchivesBannerInLayout = ForumsClient.shared.currentArchivesTimeframe != nil
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    private func swipeActionsConfig(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard listDataSource?.canEditItem(at: indexPath) == true else { return nil }
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            self?.listDataSource.deleteFavorite(at: indexPath)
            completion(true)
        }
        action.image = UIImage(systemName: "star.slash")
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func makeCellRegistration() -> UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item> {
        UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item> { [weak self] cell, _, item in
            guard let self else { return }
            cell.viewModel = self.listDataSource.viewModelFor(item: item)
            cell.didTapExpand = { [weak self] in
                self?.didTapDisclosureButton(in: $0)
            }
            cell.didTapFavorite = { [weak self] in
                self?.didTapStarButton(in: $0)
            }
            // Show the inline delete accessory for favorite-forum rows in edit mode.
            if case .favoriteForum = item {
                cell.accessories = [.delete(displayed: .whenEditing, actionHandler: { [weak self, weak cell] in
                    guard let self,
                          let cell,
                          let path = self.collectionView.indexPath(for: cell)
                    else { return }
                    self.listDataSource.deleteFavorite(at: path)
                })]
            } else {
                cell.accessories = []
            }
        }
    }

    private func makeHeaderRegistration() -> UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView> {
        UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            guard let self else { return }
            header.viewModel = .init(
                backgroundColor: self.theme["listHeaderBackgroundColor"],
                font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular),
                sectionName: self.listDataSource.titleForSection(indexPath.section),
                textColor: self.theme["listHeaderTextColor"])
        }
    }

    private func makeArchivesBannerRegistration() -> UICollectionView.SupplementaryRegistration<ForumsArchivesBannerView> {
        UICollectionView.SupplementaryRegistration<ForumsArchivesBannerView>(elementKind: Self.archivesBannerElementKind) { [weak self] view, _, _ in
            guard let self else { return }
            self.archivesBannerView = view
            self.configureArchivesBannerView(view)
        }
    }

    private func configureArchivesBannerView(_ view: ForumsArchivesBannerView) {
        guard let timeframe = ForumsClient.shared.currentArchivesTimeframe else { return }
        view.configure(
            text: ThreadsTableViewController.archivesBannerText(timeframe),
            backgroundColor: theme[uicolor: "archivesBannerBackgroundColor"],
            textColor: theme[uicolor: "archivesBannerTextColor"],
            font: UIFont.preferredFontForTextStyle(.body, sizeAdjustment: -2.5, weight: .semibold))
        view.onTap = { [weak self] in self?.showArchives() }
    }

    /// Reflects the current archives timeframe in the banner. Rebuilds the layout when the banner needs
    /// to appear or disappear; otherwise updates the existing banner's text in place (the layout won't
    /// re-dequeue it for an active→active date change).
    private func syncArchivesBanner() {
        let nowActive = ForumsClient.shared.currentArchivesTimeframe != nil
        if nowActive != isArchivesBannerInLayout {
            rebuildLayout()
        } else if nowActive, let view = archivesBannerView {
            configureArchivesBannerView(view)
        }
    }

    private func refreshIfNecessary() {
        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) {
            refresh()
        }
    }

    private func refresh() {
        Task {
            do {
                try await ForumsClient.shared.taxonomizeForums()
                RefreshMinder.sharedMinder.didRefresh(.forumList)
                migrateFavoriteForumsFromSettings()
            } catch {
                logger.error("Could not taxonomize forums: \(error)")
            }

            stopAnimatingPullToRefresh()
        }
    }

    private func migrateFavoriteForumsFromSettings() {
        // TODO: this shouldn't be the view controller's responsibility.
        // In Awful 3.2, favorite forums moved from UserDefaults to the ForumMetadata entity in Core Data.
        if let forumIDs = SettingsMigration.favoriteForums(.standard) {
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs: forumIDs.map(\.rawValue), in: managedObjectContext)
            for (i, metadata) in zip(0..., metadatas) {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            do {
                try managedObjectContext.save()
            }
            catch {
                fatalError("error saving: \(error)")
            }
            SettingsMigration.forgetFavoriteForums(.standard)
        }
    }

    private func updateBadgeValue(_ unreadCount: Int) {
        tabBarItem?.badgeValue = {
            guard showUnreadAnnouncementsBadge else { return nil }

            return unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }()
    }

    private func updateEditingState(favoriteCount: Int) {
        if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            // Reserve left-side width matching the right-side icon cluster so the centered
            // title isn't pushed off-center — same balancing spacer as BookmarksTableViewController.
            let spacer = UIBarButtonItem(customView: UIView(frame: CGRect(x: 0, y: 0, width: 72, height: 44)))
            let items = favoriteCount > 0 ? [editButtonItem, spacer] : [spacer]
            navigationItem.setLeftBarButtonItems(items, animated: true)
        } else {
            navigationItem.setLeftBarButton(favoriteCount > 0 ? editButtonItem : nil, animated: true)
        }

        if isEditing, favoriteCount == 0 {
            setEditing(false, animated: true)
        }
    }

    func openForum(_ forum: Forum, animated: Bool) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let threadList = ThreadsTableViewController(forum: forum)
        navigationController?.pushViewController(threadList, animated: animated)
    }

    func openAnnouncement(_ announcement: Announcement) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let vc = AnnouncementViewController(announcement: announcement)
        showDetailViewController(vc, sender: self)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override var undoManager: UndoManager? {
        return listDataSource.undoManager
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        listDataSource = try! ForumListDataSource(
            managedObjectContext: managedObjectContext,
            collectionView: collectionView,
            cellRegistration: cellRegistration,
            supplementaryViewProvider: { [weak self] cv, kind, indexPath in
                guard let self else { return nil }
                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    return cv.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
                case ForumsTableViewController.archivesBannerElementKind:
                    return cv.dequeueConfiguredReusableSupplementary(using: self.archivesBannerRegistration, for: indexPath)
                default:
                    return nil
                }
            }
        )
        listDataSource.delegate = self

        // Show/hide (and refresh) the archives banner as the timeframe is set/removed elsewhere.
        NotificationCenter.default.publisher(for: ForumsClient.archivesTimeframeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncArchivesBanner() }
            .store(in: &cancellables)

        // Now that the data source exists, rebuild the layout with a swipe-actions
        // provider that consults it.
        rebuildLayout()

        // 14pt of bottom breathing room — equivalent of the old tableFooterView trick.
        collectionView.contentInset.bottom = tableBottomMargin

        pullToRefreshBlock = { [weak self] in
            self?.refresh()
        }

        updateRightBarButtons()

        // Rebuild the right-side buttons when Search availability or Archives ownership changes.
        $canSendPrivateMessages
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateRightBarButtons() }
            .store(in: &cancellables)
        $hasArchives
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateRightBarButtons() }
            .store(in: &cancellables)
    }

    /// The overflow menu: Archives (upgrade owners only) then SAclopedia.
    private func moreMenu() -> UIMenu {
        let glossaryAction = UIAction(
            title: "SAclopedia",
            image: UIImage(systemName: "book.closed")
        ) { [weak self] _ in
            self?.showGlossary()
        }
        let archivesAction = UIAction(
            title: "Archives",
            image: UIImage(systemName: "clock.arrow.circlepath")
        ) { [weak self] _ in
            self?.showArchives()
        }
        return UIMenu(title: "", children: hasArchives ? [archivesAction, glossaryAction] : [glossaryAction])
    }

    /// Builds the Search + overflow (⋯) buttons as an icon pair, mirroring
    /// `BookmarksTableViewController`'s Filter/Search combo. Search uses the `quick-look`
    /// asset icon and is gated on PM privileges; the overflow menu is for everyone.
    /// Right-bar items are ordered right-to-left, so ⋯ keeps the rightmost spot with Search to its left.
    ///
    /// iOS 26's iPad navigation bar mishandles a menu-bearing bar button placed beside another item —
    /// the menu won't open and the spacing is off. Match `BookmarksTableViewController`: on iOS 26 iPad
    /// pack both icons into a single customView stack, driving the ⋯ menu ourselves via
    /// `showsMenuAsPrimaryAction` and routing the Search icon through
    /// `makeSidebarImageHostingView` so the glass sidebar doesn't mis-tint it.
    private func updateRightBarButtons() {
        let canSearch = canSendPrivateMessages

        if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            // Button text/image color comes from `navigationBar.tintColor` (see
            // NavigationController.configureButtonAppearance), so these inherit it. `.normal` tint
            // adjustment keeps them from dimming, matching BookmarksTableViewController.
            let moreButton = UIButton(type: .system)
            moreButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
            // Match the Search icon's 20pt hosting size. `ellipsis.circle`'s ring reads a touch
            // larger, so render it slightly under 20pt so the pair looks evenly sized.
            moreButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18), forImageIn: .normal)
            moreButton.showsMenuAsPrimaryAction = true
            moreButton.menu = moreMenu()
            moreButton.accessibilityLabel = "More"
            moreButton.tintAdjustmentMode = .normal

            var arranged: [UIView] = []
            if canSearch, let searchImage = UIImage(named: "quick-look") {
                // The iPad glass sidebar tints plain UIButton images via vibrancy, so route
                // the Search icon through the SwiftUI `.glassEffect(.identity)` hosting view
                // to preserve the theme's navigation-bar tint — same as Bookmarks' Search.
                let searchHosting = NavigationController.makeSidebarImageHostingView(
                    image: searchImage,
                    accessibilityLabel: "Search",
                    target: self,
                    action: #selector(searchForums)
                )
                arranged.append(searchHosting)
            }
            arranged.append(moreButton)
            let stack = UIStackView(arrangedSubviews: arranged)
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            navigationItem.setRightBarButtonItems([UIBarButtonItem(customView: stack)], animated: false)
            // This path tints itself (Search via `makeSidebarImageHostingView`'s `.themed()`
            // SwiftUI view, ⋯ via its inherited tint), so drop the standard-path references.
            moreButtonView = nil
            searchButtonView = nil
            return
        }

        // Build both as customView UIButtons sized to their icons, matching
        // BookmarksTableViewController's Filter/Search pair. A standard
        // `UIBarButtonItem(image:)` reserves a wide (~44pt) tap area, which
        // spreads the grouped glass cluster apart; icon-sized customViews pack
        // the pair tightly together like Bookmarks.
        let moreButton = UIButton(type: .system)
        moreButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.menu = moreMenu()
        moreButton.accessibilityLabel = "More"
        if #available(iOS 26.0, *) {
            moreButton.tintAdjustmentMode = .normal
        }
        moreButtonView = moreButton
        let moreItem = UIBarButtonItem(customView: moreButton)

        guard canSearch else {
            searchButtonView = nil
            navigationItem.setRightBarButtonItems([moreItem], animated: true)
            updateButtonColors()
            return
        }

        let searchButton = UIButton(type: .system)
        searchButton.setImage(UIImage(named: "quick-look"), for: .normal)
        searchButton.addTarget(self, action: #selector(searchForums), for: .touchUpInside)
        searchButton.accessibilityLabel = "Search"
        if #available(iOS 26.0, *) {
            searchButton.tintAdjustmentMode = .normal
        }
        searchButtonView = searchButton
        let searchItem = UIBarButtonItem(customView: searchButton)
        navigationItem.setRightBarButtonItems([moreItem, searchItem], animated: true)
        updateButtonColors()
    }

    /// Applies the navigation-bar button tint, mirroring `BookmarksTableViewController.updateButtonColors()`.
    /// iOS 26's glass capsule doesn't dynamically tint customView buttons — a nilled tint falls back to
    /// system blue — so set the theme-appropriate color explicitly. (The overflow ⋯ and Search have no
    /// active/selected state, so there's no alpha dimming to mirror.)
    private func updateButtonColors() {
        if #available(iOS 26.0, *) {
            // Explicit tint color prevents system default blue when NavigationController sets tintColor = nil.
            let buttonTintColor = theme["mode"] == "dark" ? UIColor.white : UIColor.black
            moreButtonView?.tintColor = buttonTintColor
            searchButtonView?.tintColor = buttonTintColor
        } else {
            let normalColor = theme[uicolor: "navigationBarTextColor"]
            moreButtonView?.tintColor = normalColor
            searchButtonView?.tintColor = normalColor
        }
    }

    @objc private func searchForums() {
        guard let navigationController else { return }
        // Picks up where the last search left off, when its results are still good.
        SearchFormViewController.push(
            SearchFormViewController.makeStack(restoring: LastSearchStore.record, handlers: .awful),
            onto: navigationController)
    }

    @objc private func showGlossary() {
        let glossary = GlossaryHostingController()
        if traitCollection.userInterfaceIdiom == .pad {
            glossary.modalPresentationStyle = .pageSheet
        } else {
            glossary.modalPresentationStyle = .fullScreen
        }
        present(glossary, animated: true)
    }

    @objc private func showArchives() {
        present(ArchivesHostingController(), animated: true)
    }

    override func themeDidChange() {
        if isViewLoaded {
            rebuildLayout()
            // The layout may reuse the banner without re-dequeuing it, so refresh its colors directly.
            if let view = archivesBannerView {
                configureArchivesBannerView(view)
            }
            updateButtonColors()
        }

        super.themeDidChange()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = editing
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        refreshIfNecessary()

        // Catch a timeframe change made from a thread list while this screen was covered.
        syncArchivesBanner()

        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        resignFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        undoManager?.removeAllActions()
    }

    // MARK: Actions

    private func didTapDisclosureButton(in cell: UICollectionViewCell) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let indexPath = collectionView.indexPath(for: cell),
              let forum = listDataSource.item(at: indexPath) as? Forum
        else { return }

        if forum.metadata.showsChildrenInForumList {
            forum.collapse()
        } else {
            forum.expand()
        }

        try! forum.managedObjectContext!.save()
    }

    private func didTapStarButton(in cell: UICollectionViewCell) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let indexPath = collectionView.indexPath(for: cell),
              let forum = listDataSource.item(at: indexPath) as? Forum
        else { return }

        if forum.metadata.favorite {
            forum.metadata.favorite = false
        } else {
            forum.metadata.favorite = true
            forum.metadata.favoriteIndex = listDataSource.nextFavoriteIndex
        }
        forum.tickleForFetchedResultsController()

        try! forum.managedObjectContext!.save()
    }
}

private let tableBottomMargin: CGFloat = 14
private let tableSeparatorLeftMargin: CGFloat = 46

extension ForumsTableViewController: ForumListDataSourceDelegate {
    func themeForCells(in dataSource: ForumListDataSource) -> Theme {
        return theme
    }
}

// MARK: UICollectionViewDelegate
extension ForumsTableViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch listDataSource.item(at: indexPath) {
        case let announcement as Announcement:
            openAnnouncement(announcement)

        case let forum as Forum:
            openForum(forum, animated: true)

        default:
            assertionFailure("unknown object type in forums list")
        }
    }

    override func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return listDataSource.proposedTargetIndexPath(for: originalIndexPath, proposed: proposedIndexPath)
    }
}

extension ForumsTableViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .forumList
    }
}

/// The full-width maroon "Archives view: …" banner pinned above the forum list. Tapping it reopens
/// the archives sheet.
private final class ForumsArchivesBannerView: UICollectionReusableView {
    private let label = UILabel()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }

    func configure(text: String, backgroundColor: UIColor?, textColor: UIColor?, font: UIFont) {
        label.text = text
        label.textColor = textColor
        label.font = font
        self.backgroundColor = backgroundColor
    }
}
