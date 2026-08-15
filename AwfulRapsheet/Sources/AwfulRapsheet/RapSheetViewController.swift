//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulSettings
import AwfulTheming
import ScrollViewDelegateMultiplexer
import UIKit

/// Displays a list of probations and bans, rendered in a web view (like the posts page). Serves as both the
/// Leper's Colony tab (`user == nil`) and a single user's Rap Sheet (`user != nil`).
public final class RapSheetViewController: ViewController {

    private let user: User?

    /// What the app does on our behalf (rendering machinery, refresh bookkeeping, navigation).
    private let handlers: RapsheetHandlers

    /// True for the Leper's Colony tab root, false for a single user's rap sheet.
    public var isLepersColony: Bool { user == nil }

    // MARK: Paging state

    /// The currently-displayed page; `0` until the first load completes.
    private var page = 0
    private var pageCount = 1
    private var isLoading = false

    /// Already-fetched pages, keyed by requested page number, so Back/Forward doesn't refetch.
    /// Invalidated on refresh and filter change.
    private var pageCache: [Int: LepersColonyScrapeResult] = [:]

    // MARK: Endless scroll (Leper's Colony tab only)

    @FoilDefaultStorage(Settings.endlessScrollLepers) private var endlessScrollLepers

    /// Punishments grouped by the page they were fetched from, in display order, so full re-renders
    /// (theme change, web process termination) can reproduce the accumulated document with dividers.
    private var punishmentPages: [(page: Int, punishments: [LepersColonyScrapeResult.Punishment])] = []
    private var isAppending = false
    private var scrollViewDelegateMux: ScrollViewDelegateMultiplexer?

    private var isEndlessScrolling: Bool { isLepersColony && endlessScrollLepers }

    // MARK: Filtering (Leper's Colony tab only)

    private var filter = LepersColonyFilter()
    private var filterOptions: LepersColonyScrapeResult.FilterOptions?

    private var currentPunishments: [LepersColonyScrapeResult.Punishment] = []

    private var loadingView: UIView?
    private var loadingBackground: UIView?

    private lazy var banDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var renderView: RapsheetRenderer = {
        let renderer = handlers.makeRenderer()
        renderer.didTapPunishmentPost = { [weak self] postID in
            guard !postID.isEmpty else { return }
            self?.openPost(id: postID)
        }
        renderer.didTapLink = { [weak self] url in
            guard let self else { return }
            self.handlers.handleLink(url, self)
        }
        renderer.renderProcessDidTerminate = { [weak self] in
            self?.renderPunishments()
        }
        return renderer
    }()

    private lazy var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))

    /// Keeps the paging controls from sitting flush against the root tab bar.
    private static let toolbarBottomPadding: CGFloat = 2

    /// Size of the nav-bar icons on the iOS 26 iPad path. `makeSidebarImageHostingView` scales the
    /// image to fill this box, so these circle-enclosed symbols need to come in under the 20pt other
    /// tabs use for their (unenclosed) icons to read the same size.
    private static let padIconPointSize: CGFloat = 17

    private lazy var doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            // The pull-to-refresh control shows its own spinner, so skip the full loading overlay.
            self.pageCache.removeAll()
            Task { await self.load(max(self.page, 1), showsLoadingOverlay: false) }
        }, for: .valueChanged)
        return control
    }()

    /// Nav-bar Filter/Refresh button views on the standard (non–iOS 26 iPad) path, kept so
    /// `updateButtonColors()` can retint them on theme changes — mirroring `ForumsTableViewController`.
    private var filterButtonView: UIButton?
    private var refreshButtonView: UIButton?

    /// Top-left "More…" button, shown only while endless scrolling. Its menu is the way back to the paging
    /// controls, which are hidden while endless scroll is on.
    private var moreButtonView: UIButton?

    // MARK: Toolbar items

    private lazy var backItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(image: UIImage(named: "arrowleft")) { [weak self] _ in
            guard let self, self.page > 1, !self.isLoading else { return }
            Task { await self.load(self.page - 1) }
        })
        item.accessibilityLabel = "Previous page"
        return item
    }()

    private lazy var currentPageItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction { [weak self] action in
            self?.showPagePicker(from: action.sender as? UIBarButtonItem)
        })
        item.possibleTitles = ["8888 / 8888"]
        item.accessibilityHint = "Opens page picker"
        return item
    }()

    private lazy var forwardItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(image: UIImage(named: "arrowright")) { [weak self] _ in
            guard let self, self.page < self.pageCount, !self.isLoading else { return }
            Task { await self.load(self.page + 1) }
        })
        item.accessibilityLabel = "Next page"
        return item
    }()

    public init(user: User? = nil, handlers: RapsheetHandlers) {
        self.user = user
        self.handlers = handlers
        super.init(nibName: nil, bundle: nil)

        if user == nil {
            title = String(localized: "Leper’s Colony", bundle: .module)
            // Tab bar item title is set in `themeDidChange()` as some themes do not show titles.
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = String(localized: "Rap Sheet", bundle: .module)
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .formSheet
        }

        themeDidChange()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(renderView.view)
        view.addSubview(toolbar)
        renderView.view.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // The render view fills below the nav bar all the way to the screen bottom, so content scrolls
            // behind the floating toolbar and the (glass) tab bar. `updateScrollViewInsets()` reserves the
            // matching bottom inset so content still clears them.
            renderView.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            renderView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.toolbarBottomPadding),
        ])

        renderView.scrollView.contentInsetAdjustmentBehavior = .never
        renderView.scrollView.refreshControl = refreshControl

        // Watch for nearing the bottom to drive endless scroll. (The multiplexer preserves WKWebView's own scroll-view delegation.)
        scrollViewDelegateMux = ScrollViewDelegateMultiplexer(scrollView: renderView.scrollView)
        scrollViewDelegateMux?.addDelegate(self)

        toolbar.items = makeToolbarItems()
        updateToolbar()
        updateRightBarButtons()

        // Re-apply the theme now that the render view and toolbar are in the hierarchy.
        themeDidChange()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Whether we need a Done button depends on how we were presented, which isn't known until now.
        updateRightBarButtons()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewInsets()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateScrollViewInsets()
    }

    /// Reserves bottom space equal to the floating toolbar plus the tab bar, so the render view can fill the
    /// screen (content visible behind the glass bars) without the last rows being hidden underneath.
    private func updateScrollViewInsets() {
        guard isViewLoaded else { return }
        // With the paging toolbar hidden (endless scroll), only the tab bar needs clearing.
        let bottomInset = toolbar.isHidden
            ? max(0, view.bounds.maxY - view.safeAreaLayoutGuide.layoutFrame.maxY)
            : max(0, view.bounds.maxY - toolbar.frame.minY)
        renderView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        renderView.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isLepersColony {
            // Refresh when the tab is shown, but only if it's been a while (like the other tabs), so
            // returning from a post doesn't reload every time.
            if page == 0 || handlers.shouldRefreshLepersColony() {
                refresh()
            }
        } else {
            refreshIfNecessary()
        }
    }

    public override func themeDidChange() {
        super.themeDidChange()

        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = if isLepersColony {
                String(localized: "Lepers", bundle: .module)
            } else {
                String(localized: "Rap Sheet", bundle: .module)
            }
        }

        guard isViewLoaded else { return }

        toolbar.tintColor = theme["toolbarTextColor"]
        configureToolbarAppearance()
        updateButtonColors()
        refreshControl.tintColor = theme["listTextColor"]

        renderView.setThemeStylesheet(theme[string: "postsViewCSS"] ?? "")
    }

    /// A clear glass bar on iOS 26 (only the liquid-glass item pills show), opaque before. A `barTintColor`
    /// (which we deliberately don't set) would force an opaque grey bar even on iOS 26. Uses the same
    /// transparent-background idiom as `NavigationController`'s iOS 26 nav bar.
    private func configureToolbarAppearance() {
        let appearance = UIToolbarAppearance()
        if #available(iOS 26.0, *), toolbar.isTranslucent {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundImage = nil
        } else {
            // Force opaque pre-26 so scrolled content doesn't bleed through the toolbar.
            toolbar.isTranslucent = false
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme["backgroundColor"]
        }
        appearance.shadowImage = nil
        appearance.shadowColor = nil
        toolbar.standardAppearance = appearance
        toolbar.compactAppearance = appearance
        toolbar.scrollEdgeAppearance = appearance
        toolbar.compactScrollEdgeAppearance = appearance
    }

    // MARK: - Loading

    private func refreshIfNecessary() {
        guard page == 0, !isLoading else { return }
        Task { await load(1) }
    }

    private func refresh() {
        guard !isLoading else { return }
        pageCache.removeAll()
        Task { await load(max(page, 1)) }
    }

    private func load(_ pageToLoad: Int, showsLoadingOverlay: Bool = true) async {
        isLoading = true
        updateToolbar()
        if showsLoadingOverlay {
            showLoadingView()
        }
        defer {
            isLoading = false
            refreshControl.endRefreshing()
            hideLoadingView()
            updateToolbar()
        }

        do {
            let result: LepersColonyScrapeResult
            if let cached = pageCache[pageToLoad] {
                result = cached
            } else {
                result = try await ForumsClient.shared.listPunishments(of: user, page: pageToLoad, filter: filter)
                pageCache[pageToLoad] = result
            }
            page = result.pageNumber ?? pageToLoad
            pageCount = result.pageCount ?? max(pageCount, page)
            if let options = result.filterOptions {
                filterOptions = options
            }
            currentPunishments = result.punishments
            // A fresh page load collapses any endless-scroll accumulation.
            punishmentPages = [(page, result.punishments)]
            renderPunishments()
            if isLepersColony {
                handlers.didRefreshLepersColony()
            }
        } catch {
            present(UIAlertController(networkError: error), animated: true)
        }
    }

    /// Endless scroll: fetches the next page and appends its punishments to the rendered document, preceded
    /// by a "Page x of y" divider. Called repeatedly as the user scrolls near the bottom; all gating happens
    /// here so calls are cheap and idempotent.
    private func appendNextPageIfNeeded() {
        guard isEndlessScrolling, !isLoading, !isAppending, page >= 1, page < pageCount else { return }
        isAppending = true
        let nextPage = page + 1
        Task { [weak self] in
            defer { self?.isAppending = false }
            guard let self else { return }
            do {
                let result = try await ForumsClient.shared.listPunishments(of: user, page: nextPage, filter: filter)
                // Bail if a full load raced us and the document no longer ends with the page we appended after.
                guard self.isEndlessScrolling, self.page == nextPage - 1 else { return }
                self.pageCache[nextPage] = result
                self.page = result.pageNumber ?? nextPage
                self.pageCount = result.pageCount ?? max(self.pageCount, self.page)
                // Banlist rows shift as new punishments arrive (newest first), so drop rows we already show.
                let existing = Set(self.currentPunishments)
                let fresh = result.punishments.filter { !existing.contains($0) }
                guard !fresh.isEmpty else {
                    self.updateToolbar()
                    return
                }
                self.punishmentPages.append((self.page, fresh))
                self.currentPunishments.append(contentsOf: fresh)
                let rowsHTML = self.handlers.renderTemplate([
                    "rowsOnly": true,
                    "punishments": self.rows(for: fresh, pageDivider: "Page \(self.page) of \(self.pageCount)"),
                ])
                await self.renderView.append(html: rowsHTML, containerID: "punishments")
                self.updateToolbar()
            } catch {
                // Stay quiet; scrolling near the bottom again retries.
            }
        }
    }

    // MARK: - Rendering

    private func renderPunishments() {
        // Build the context on the main actor (it reads the theme), then render off-main like the posts page.
        let context = renderContext()
        let renderTemplate = handlers.renderTemplate
        Task.detached(priority: .userInitiated) {
            let html = renderTemplate(context)
            await self.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
        }
    }

    private func renderContext() -> [String: Any] {
        // Re-emit page dividers so a full re-render (theme change, web process termination) reproduces the endless-scroll accumulation.
        var allRows: [[String: Any]] = []
        if punishmentPages.count > 1 {
            for (i, group) in punishmentPages.enumerated() {
                let divider = i == 0 ? nil : "Page \(group.page) of \(pageCount)"
                allRows += rows(for: group.punishments, pageDivider: divider)
            }
        } else {
            allRows = rows(for: currentPunishments, pageDivider: nil)
        }

        return [
            "stylesheet": theme[string: "postsViewCSS"] ?? "",
            "lepersCSS": (try? theme.stylesheet(named: "lepers")) ?? "",
            "emptyText": String(localized: "rap-sheet.empty", bundle: .module),
            "punishments": allRows,
        ]
    }

    /// Template contexts for a run of punishment rows, with an optional "Page x of y" divider before the first row.
    private func rows(
        for punishments: [LepersColonyScrapeResult.Punishment],
        pageDivider: String?
    ) -> [[String: Any]] {
        punishments.enumerated().map { i, punishment in
            let sentenceClass = Self.sentenceClass(for: punishment.sentence)
            var row: [String: Any] = [
                "sentenceClass": sentenceClass,
                "iconURL": iconURL(for: sentenceClass),
                "subjectUsername": punishment.subjectUsername,
                "subtitle": subtitle(for: punishment),
                "reasonHTML": punishment.reason,
            ]
            if let postID = punishment.post?.rawValue {
                row["postID"] = postID
            }
            if i == 0, let pageDivider {
                row["pageDivider"] = pageDivider
            }
            return row
        }
    }

    // MARK: - Loading overlay

    private func showLoadingView() {
        guard loadingView == nil else { return }

        // Keep the floating toolbar above the overlay so paging stays visible/interactive.
        let loadingView = handlers.makeLoadingView(theme)
        loadingView.alpha = 1
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        // Inserting triggers the loading view's `retheme()`, which sets its background color.
        view.insertSubview(loadingView, belowSubview: toolbar)

        // A full-height backing in the loading view's own color hides the existing content behind the
        // toolbar and tab bar too, while the loading view (pinned to the visible area) keeps its spinner
        // vertically centered in what the user actually sees.
        let background = UIView()
        background.backgroundColor = loadingView.backgroundColor
        background.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(background, belowSubview: loadingView)

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: renderView.view.topAnchor),
            background.leadingAnchor.constraint(equalTo: renderView.view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: renderView.view.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: renderView.view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: renderView.view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: renderView.view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])
        self.loadingView = loadingView
        self.loadingBackground = background
    }

    private func hideLoadingView() {
        guard let loadingView else { return }
        let background = loadingBackground
        self.loadingView = nil
        self.loadingBackground = nil
        UIView.animate(withDuration: 0.2, animations: {
            loadingView.alpha = 0
            background?.alpha = 0
        }, completion: { _ in
            loadingView.removeFromSuperview()
            background?.removeFromSuperview()
        })
    }

    private func subtitle(for punishment: LepersColonyScrapeResult.Punishment) -> String {
        var components: [String] = []
        if let date = punishment.date {
            components.append(banDateFormatter.string(from: date))
        }
        if !punishment.requesterUsername.isEmpty {
            components.append("by \(punishment.requesterUsername)")
        }
        return components.joined(separator: " ")
    }

    private static func sentenceClass(for sentence: LepersColonyScrapeResult.Punishment.Sentence?) -> String {
        switch sentence {
        case .probation?: return "probation"
        case .permaban?: return "permaban"
        case .ban?, .autoban?, .none: return "ban"
        }
    }

    /// The two ban icons are loose bundle resources; probation lives only in an asset catalog (unreachable
    /// by `awful-resource://`), so the app serves it once from memory via `awful-image://`.
    private func iconURL(for sentenceClass: String) -> String {
        switch sentenceClass {
        case "probation": return probationIconURL
        case "permaban": return "awful-resource://title-permabanned.gif"
        default: return "awful-resource://title-banned.gif"
        }
    }

    private lazy var probationIconURL: String = handlers.probationIconURL()

    // MARK: - Toolbar

    /// The toolbar carries only the paging controls; Filter and Refresh live in the navigation bar.
    private func makeToolbarItems() -> [UIBarButtonItem] {
        [.flexibleSpace(), backItem, currentPageItem, forwardItem, .flexibleSpace()]
    }

    private func updateToolbar() {
        // Endless scroll replaces the paging controls; the near-bottom trigger loads the next page instead.
        toolbar.isHidden = isEndlessScrolling
        let current = max(page, 1)
        let total = max(pageCount, current)
        currentPageItem.title = "\(current) / \(total)"
        currentPageItem.accessibilityLabel = "Page \(current) of \(total)"
        currentPageItem.isEnabled = total > 1
        backItem.isEnabled = current > 1 && !isLoading
        forwardItem.isEnabled = current < total && !isLoading
    }

    // MARK: - Endless scroll

    private func startEndlessScroll() {
        endlessScrollLepers = true
        updateToolbar()
        updateRightBarButtons()
        updateScrollViewInsets()
        // The user may already be parked at the bottom.
        appendNextPageIfNeeded()
    }

    private func exitEndlessScroll() {
        endlessScrollLepers = false
        updateToolbar()
        updateRightBarButtons()
        updateScrollViewInsets()
    }

    // MARK: - Navigation bar

    /// Builds the Refresh + Filter icon pair, mirroring `ForumsTableViewController`'s Search + ⋯ combo.
    /// Right-bar items are ordered right-to-left, so Refresh ends up left of Filter (and both left of Done,
    /// where there is one).
    ///
    /// iOS 26's iPad navigation bar spreads adjacent bar buttons apart, so — matching
    /// `ForumsTableViewController` — pack both icons into a single customView stack there, routing them
    /// through `makeSidebarImageHostingView` so the glass sidebar doesn't mis-tint them.
    private func updateRightBarButtons() {
        // Presented as the root of our own navigation controller, so Done is the only way out.
        let doneItems = presentingViewController != nil && navigationController?.viewControllers.count == 1
            ? [doneItem]
            : []

        // Filtering and refreshing are only meaningful on the whole-colony tab.
        guard isLepersColony else {
            filterButtonView = nil
            refreshButtonView = nil
            moreButtonView = nil
            navigationItem.setRightBarButtonItems(doneItems, animated: false)
            return
        }

        // The filled icon shows at a glance that this isn't the site's default unfiltered view.
        let filterImage = UIImage(systemName: filter == LepersColonyFilter()
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill")
        let refreshImage = UIImage(systemName: "arrow.clockwise")

        if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            // The iPad glass sidebar tints plain UIButton images via vibrancy, so route both icons through
            // the SwiftUI `.glassEffect(.identity)` hosting view to preserve the theme's tint.
            var arranged: [UIView] = []
            if let refreshImage {
                arranged.append(handlers.makeSidebarImageButton(
                    refreshImage,
                    "Refresh",
                    Self.padIconPointSize,
                    self,
                    #selector(refreshButtonTapped)
                ))
            }
            if let filterImage {
                arranged.append(handlers.makeSidebarImageButton(
                    filterImage,
                    "Filter",
                    Self.padIconPointSize,
                    self,
                    #selector(filterButtonTapped)
                ))
            }
            let stack = UIStackView(arrangedSubviews: arranged)
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            navigationItem.setRightBarButtonItems(doneItems + [UIBarButtonItem(customView: stack)], animated: false)

            if isEndlessScrolling {
                // Replace the balancing spacer with a real More… button (menu attached to a UIButton via
                // `showsMenuAsPrimaryAction` — plain UIBarButtonItem menus misbehave on iOS 26 iPad), padded
                // out to the same 72pt so the centered title stays balanced against the right-side cluster.
                let moreButton = makeMoreButton()
                moreButtonView = moreButton
                let container = UIView(frame: CGRect(x: 0, y: 0, width: 72, height: 44))
                moreButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
                container.addSubview(moreButton)
                navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: container)], animated: false)
            } else {
                moreButtonView = nil
                // Reserve left-side width matching the right-side icon cluster so the centered title isn't
                // pushed off-center — same balancing spacer as `ForumsTableViewController`.
                let spacer = UIBarButtonItem(customView: UIView(frame: CGRect(x: 0, y: 0, width: 72, height: 44)))
                navigationItem.setLeftBarButtonItems([spacer], animated: false)
            }

            // This path tints itself (via `makeSidebarImageHostingView`'s `.themed()` SwiftUI view), so drop
            // the standard-path references. The More… button still needs the explicit tint.
            filterButtonView = nil
            refreshButtonView = nil
            updateButtonColors()
            return
        }

        // Icon-sized customViews rather than plain `UIBarButtonItem(image:)`: the latter reserves a wide
        // (~44pt) tap area, which spreads the pair apart instead of packing them tightly like Forums.
        let filterButton = makeBarButton(image: filterImage, accessibilityLabel: "Filter", action: #selector(filterButtonTapped))
        let refreshButton = makeBarButton(image: refreshImage, accessibilityLabel: "Refresh", action: #selector(refreshButtonTapped))
        filterButtonView = filterButton
        refreshButtonView = refreshButton
        navigationItem.setRightBarButtonItems(
            doneItems + [UIBarButtonItem(customView: filterButton), UIBarButtonItem(customView: refreshButton)],
            animated: false
        )

        if isEndlessScrolling {
            let moreButton = makeMoreButton()
            moreButtonView = moreButton
            navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: moreButton)], animated: false)
        } else {
            moreButtonView = nil
            navigationItem.setLeftBarButtonItems([], animated: false)
        }

        updateButtonColors()
    }

    /// The top-left "More…" button shown while endless scrolling. Uses `showsMenuAsPrimaryAction` on a
    /// UIButton (rather than a UIBarButtonItem menu) so it behaves on iOS 26 iPads too.
    private func makeMoreButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        button.accessibilityLabel = "More"
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIAction(title: "Exit Endless Scroll") { [weak self] _ in
                self?.exitEndlessScroll()
            },
        ])
        if #available(iOS 26.0, *) {
            button.tintAdjustmentMode = .normal
        }
        return button
    }

    private func makeBarButton(image: UIImage?, accessibilityLabel: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = accessibilityLabel
        if #available(iOS 26.0, *) {
            button.tintAdjustmentMode = .normal
        }
        return button
    }

    /// Applies the navigation-bar button tint, mirroring `ForumsTableViewController.updateButtonColors()`.
    /// iOS 26's glass capsule doesn't dynamically tint customView buttons — a nilled tint falls back to
    /// system blue — so set the theme-appropriate color explicitly.
    private func updateButtonColors() {
        let tintColor: UIColor?
        if #available(iOS 26.0, *) {
            // An explicit tint prevents the system default blue when `NavigationController` sets tintColor = nil.
            tintColor = theme["mode"] == "dark" ? UIColor.white : UIColor.black
        } else {
            tintColor = theme[uicolor: "navigationBarTextColor"]
        }
        filterButtonView?.tintColor = tintColor
        refreshButtonView?.tintColor = tintColor
        moreButtonView?.tintColor = tintColor
    }

    @objc private func filterButtonTapped() {
        showDisplayOptions()
    }

    @objc private func refreshButtonTapped() {
        refresh()
    }

    private func showPagePicker(from item: UIBarButtonItem?) {
        guard pageCount > 1, !isLoading else { return }
        let picker = PagePickerViewController(
            pageCount: pageCount,
            currentPage: max(page, 1),
            endlessScrollToggle: isLepersColony ? (
                title: endlessScrollLepers ? "Exit Endless Scroll" : "Start Endless Scroll",
                action: { [weak self] in
                    guard let self else { return }
                    if self.endlessScrollLepers {
                        self.exitEndlessScroll()
                    } else {
                        self.startEndlessScroll()
                    }
                }
            ) : nil,
            onSelect: { [weak self] selected in
                guard let self, selected != self.page else { return }
                Task { await self.load(selected) }
            }
        )
        picker.popoverPresentationController?.barButtonItem = item
        present(picker, animated: true)
    }

    private func showDisplayOptions() {
        let controller = LepersFilterHostingController(
            filter: filter,
            options: filterOptions,
            onApply: { [weak self] newFilter in
                guard let self, newFilter != self.filter else { return }
                self.filter = newFilter
                self.pageCache.removeAll()
                // Reflect the new filter in the nav bar's Filter icon (plain vs. filled).
                self.updateRightBarButtons()
                Task { await self.load(1) }
            }
        )
        present(controller, animated: true)
    }

    /// Opens the post a user was punished for. Placement is the handler's call: from the tab it shows
    /// in the split-view detail column (like tapping a thread in the forums list), while the modal Rap
    /// Sheet dismisses and lets the app's router place the post.
    private func openPost(id postID: String) {
        handlers.openPost(postID, self)
    }

    @objc private func didTapDone() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIScrollViewDelegate (endless scroll trigger)

extension RapSheetViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // WKWebView may trigger scroll events on background threads during content loading (same caveat as PostsPageView).
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.scrollViewDidScroll(scrollView)
            }
            return
        }

        // Ask for the next page when nearing the bottom. (`appendNextPageIfNeeded` does all its own gating, so this is cheap.)
        let distanceToBottom = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if scrollView.contentSize.height > 0, distanceToBottom < scrollView.bounds.height * 1.5 {
            appendNextPageIfNeeded()
        }
    }
}

// MARK: - Page picker

/// A compact page-jump popover, mirroring the posts page's `Selectotron`.
private final class PagePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIPopoverPresentationControllerDelegate {
    private let pageCount: Int
    private let initialPage: Int
    private let endlessScrollToggle: (title: String, action: () -> Void)?
    private let onSelect: (Int) -> Void
    private let picker = UIPickerView()

    init(
        pageCount: Int,
        currentPage: Int,
        endlessScrollToggle: (title: String, action: () -> Void)? = nil,
        onSelect: @escaping (Int) -> Void
    ) {
        self.pageCount = pageCount
        self.initialPage = currentPage
        self.endlessScrollToggle = endlessScrollToggle
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 240, height: endlessScrollToggle == nil ? 240 : 296)
        modalPresentationStyle = .popover
        // Stay a popover on iPhone too (like `Selectotron`); otherwise this adapts to a full-screen sheet.
        popoverPresentationController?.delegate = self
    }

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let theme = Theme.defaultTheme()
        view.backgroundColor = theme["sheetBackgroundColor"] ?? theme["backgroundColor"]

        picker.dataSource = self
        picker.delegate = self
        picker.selectRow(min(max(initialPage - 1, 0), pageCount - 1), inComponent: 0, animated: false)

        let goButton = UIButton(type: .system)
        goButton.setTitle(String(localized: "Go", bundle: .module), for: .normal)
        goButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        goButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let selected = self.picker.selectedRow(inComponent: 0) + 1
            self.dismiss(animated: true) { self.onSelect(selected) }
        }, for: .touchUpInside)

        var arrangedSubviews: [UIView] = [picker, goButton]
        if let endlessScrollToggle {
            let toggleButton = UIButton(type: .system)
            toggleButton.setTitle(endlessScrollToggle.title, for: .normal)
            toggleButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
            toggleButton.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.dismiss(animated: true) { endlessScrollToggle.action() }
            }, for: .touchUpInside)
            arrangedSubviews.append(toggleButton)
        }

        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -12),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { pageCount }

    /// Attributed titles (like `Selectotron`'s): plain titles render in the system label color, which can be
    /// invisible against the themed sheet background when the theme and system appearance disagree.
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let theme = Theme.defaultTheme()
        return NSAttributedString(string: "\(row + 1)", attributes: [
            .foregroundColor: theme[uicolor: "sheetTextColor"] ?? UIColor.label,
            .font: UIFont.preferredFont(forTextStyle: .body),
        ])
    }
}
