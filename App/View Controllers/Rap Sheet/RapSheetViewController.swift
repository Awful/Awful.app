//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import UIKit
import WebKit

/// Displays a list of probations and bans, rendered in a web view (like the posts page). Serves as both the
/// Leper's Colony tab (`user == nil`) and a single user's Rap Sheet (`user != nil`).
final class RapSheetViewController: ViewController {

    private let user: User?

    // MARK: Paging state

    /// The currently-displayed page; `0` until the first load completes.
    private var page = 0
    private var pageCount = 1
    private var isLoading = false

    // MARK: Filtering (Leper's Colony tab only)

    private var filter = LepersColonyFilter()
    private var filterOptions: LepersColonyScrapeResult.FilterOptions?

    private var currentPunishments: [LepersColonyScrapeResult.Punishment] = []

    private var loadingView: LoadingView?
    private var loadingBackground: UIView?

    private lazy var banDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var renderView: RenderView = {
        let renderView = RenderView()
        renderView.delegate = self
        renderView.registerMessage(DidTapPunishmentPost.self)
        return renderView
    }()

    private lazy var toolbar = Toolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))

    private lazy var doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            // The pull-to-refresh control shows its own spinner, so skip the full loading overlay.
            Task { await self.load(max(self.page, 1), showsLoadingOverlay: false) }
        }, for: .valueChanged)
        return control
    }()

    // MARK: Toolbar items

    private lazy var displayOptionsItem = UIBarButtonItem(primaryAction: UIAction(
        image: UIImage(systemName: "line.3.horizontal.decrease.circle")
    ) { [weak self] action in
        self?.showDisplayOptions(from: action.sender as? UIBarButtonItem)
    })

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

    /// Balances `displayOptionsItem` on the right so the paging controls stay centered (mirroring the posts
    /// toolbar's settings/actions symmetry); also a handy explicit reload.
    private lazy var refreshItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            guard let self, !self.isLoading else { return }
            Task { await self.load(max(self.page, 1)) }
        })
        item.accessibilityLabel = "Refresh"
        return item
    }()

    init(user: User? = nil) {
        self.user = user
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(renderView)
        view.addSubview(toolbar)
        renderView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // The render view fills below the nav bar all the way to the screen bottom, so content scrolls
            // behind the floating toolbar and the (glass) tab bar. `updateScrollViewInsets()` reserves the
            // matching bottom inset so content still clears them.
            renderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        renderView.scrollView.contentInsetAdjustmentBehavior = .never
        renderView.scrollView.refreshControl = refreshControl

        toolbar.items = makeToolbarItems()
        updateToolbar()

        // Re-apply the theme now that the render view and toolbar are in the hierarchy.
        themeDidChange()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard presentingViewController != nil && navigationController?.viewControllers.count == 1 else { return }
        navigationItem.rightBarButtonItem = doneItem
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewInsets()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateScrollViewInsets()
    }

    /// Reserves bottom space equal to the floating toolbar plus the tab bar, so the render view can fill the
    /// screen (content visible behind the glass bars) without the last rows being hidden underneath.
    private func updateScrollViewInsets() {
        guard isViewLoaded else { return }
        let bottomInset = max(0, view.bounds.maxY - toolbar.frame.minY)
        renderView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        renderView.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if user == nil {
            // Refresh when the tab is shown, but only if it's been a while (like the other tabs), so
            // returning from a post doesn't reload every time.
            if page == 0 || RefreshMinder.sharedMinder.shouldRefresh(.lepersColony) {
                refresh()
            }
        } else {
            refreshIfNecessary()
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = if user == nil {
                String(localized: "Lepers", bundle: .module)
            } else {
                String(localized: "Rap Sheet", bundle: .module)
            }
        }

        guard isViewLoaded else { return }

        toolbar.tintColor = theme["toolbarTextColor"]
        configureToolbarAppearance()
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
            let result = try await ForumsClient.shared.listPunishments(of: user, page: pageToLoad, filter: filter)
            page = result.pageNumber ?? pageToLoad
            pageCount = result.pageCount ?? max(pageCount, page)
            if let options = result.filterOptions {
                filterOptions = options
            }
            currentPunishments = result.punishments
            renderPunishments()
            if user == nil {
                RefreshMinder.sharedMinder.didRefresh(.lepersColony)
            }
        } catch {
            present(UIAlertController(networkError: error), animated: true)
        }
    }

    // MARK: - Rendering

    private func renderPunishments() {
        let html = (try? StencilEnvironment.shared.renderTemplate(.lepersColony, context: renderContext())) ?? ""
        renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
    }

    private func renderContext() -> [String: Any] {
        let rows: [[String: Any]] = currentPunishments.map { punishment in
            let sentenceClass = Self.sentenceClass(for: punishment.sentence)
            var row: [String: Any] = [
                "sentenceClass": sentenceClass,
                "iconURL": Self.iconURL(for: sentenceClass),
                "subjectUsername": punishment.subjectUsername,
                "subtitle": subtitle(for: punishment),
                "reasonHTML": punishment.reason,
            ]
            if let postID = punishment.post?.rawValue {
                row["postID"] = postID
            }
            return row
        }

        return [
            "stylesheet": theme[string: "postsViewCSS"] ?? "",
            "lepersCSS": (try? theme.stylesheet(named: "lepers")) ?? "",
            "emptyText": LocalizedString("rap-sheet.empty"),
            "punishments": rows,
        ]
    }

    // MARK: - Loading overlay

    private func showLoadingView() {
        guard loadingView == nil else { return }

        // Keep the floating toolbar above the overlay so paging stays visible/interactive.
        let loadingView = LoadingView.loadingViewWithTheme(theme)
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
            background.topAnchor.constraint(equalTo: renderView.topAnchor),
            background.leadingAnchor.constraint(equalTo: renderView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: renderView.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: renderView.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: renderView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: renderView.trailingAnchor),
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
    /// by `awful-resource://`), so it's served once from memory via `awful-image://`.
    private static func iconURL(for sentenceClass: String) -> String {
        switch sentenceClass {
        case "probation": return probationIconURL
        case "permaban": return "awful-resource://title-permabanned.gif"
        default: return "awful-resource://title-banned.gif"
        }
    }

    private static let probationIconURL: String = {
        // The path must start with "/" — `awful-image://` URLs have an empty authority, so a relative path
        // would make `URLComponents.url` nil (and `ImageURLProtocol` force-unwraps it).
        guard let image = UIImage(named: "title-probation"),
              let url = ImageURLProtocol.serveImage(image, atPath: "/leper-probation")
        else { return "" }
        return url.absoluteString
    }()

    // MARK: - Toolbar

    private func makeToolbarItems() -> [UIBarButtonItem] {
        let paging: [UIBarButtonItem] = [.flexibleSpace(), backItem, currentPageItem, forwardItem, .flexibleSpace()]
        // The display-options filter is only meaningful on the whole-colony tab. When it's shown, a refresh
        // button balances it on the right so the paging controls stay centered.
        if user == nil {
            return [displayOptionsItem] + paging + [refreshItem]
        }
        return paging
    }

    private func updateToolbar() {
        let current = max(page, 1)
        let total = max(pageCount, current)
        currentPageItem.title = "\(current) / \(total)"
        currentPageItem.accessibilityLabel = "Page \(current) of \(total)"
        currentPageItem.isEnabled = total > 1
        backItem.isEnabled = current > 1 && !isLoading
        forwardItem.isEnabled = current < total && !isLoading
    }

    private func showPagePicker(from item: UIBarButtonItem?) {
        guard pageCount > 1, !isLoading else { return }
        let picker = PagePickerViewController(pageCount: pageCount, currentPage: max(page, 1)) { [weak self] selected in
            guard let self, selected != self.page else { return }
            Task { await self.load(selected) }
        }
        picker.modalPresentationStyle = .popover
        picker.popoverPresentationController?.barButtonItem = item
        present(picker, animated: true)
    }

    private func showDisplayOptions(from item: UIBarButtonItem?) {
        let controller = LepersFilterHostingController(
            filter: filter,
            options: filterOptions,
            onApply: { [weak self] newFilter in
                guard let self, newFilter != self.filter else { return }
                self.filter = newFilter
                Task { await self.load(1) }
            }
        )
        present(controller, animated: true)
    }

    /// Opens the post a user was punished for. From the tab this shows in the split-view detail column
    /// (like tapping a thread in the forums list) rather than pushing into the sidebar the way
    /// `open(route:)` does here; the modal Rap Sheet dismisses and lets the router place the post.
    private func openPost(id postID: String) {
        if presentingViewController != nil {
            AppDelegate.instance.open(route: .post(id: postID, .noseen))
            dismiss(animated: true)
            return
        }

        // No loading overlay here: the detail's `PostsPageViewController` shows its own while it loads, so
        // the sidebar list shouldn't flash a refresh spinner just for opening a post.
        Task { @MainActor in
            do {
                let (post, page) = try await ForumsClient.shared.locatePost(id: postID, updateLastReadPost: false)
                guard let thread = post.thread else { return }
                let postsVC = PostsPageViewController(thread: thread)
                postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: false)
                postsVC.scrollPostToVisible(post)
                showDetailViewController(postsVC, sender: self)
            } catch {
                present(UIAlertController(networkError: error), animated: true)
            }
        }
    }

    @objc private func didTapDone() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: Gunk

    private struct DidTapPunishmentPost: RenderViewMessage {
        static let messageName = "didTapPunishmentPost"
        let postID: String?

        init?(rawMessage: WKScriptMessage, in renderView: RenderView) {
            assert(rawMessage.name == DidTapPunishmentPost.messageName)
            postID = (rawMessage.body as? [String: Any])?["postID"] as? String
        }
    }
}

// MARK: - RenderViewDelegate

extension RapSheetViewController: RenderViewDelegate {
    func didFinishRenderingHTML(in view: RenderView) {
        // nop
    }

    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case let message as DidTapPunishmentPost:
            guard let postID = message.postID, !postID.isEmpty else { return }
            openPost(id: postID)

        default:
            break
        }
    }

    func didTapLink(to url: URL, in view: RenderView) {
        if let route = try? AwfulRoute(url) {
            AppDelegate.instance.open(route: route)
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.open(url)
        }
    }

    func renderProcessDidTerminate(in view: RenderView) {
        renderPunishments()
    }
}

// MARK: - RestorableLocation

extension RapSheetViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        // Only the tab-root (user == nil) instance needs to advertise a route; user-specific rap sheets are pushed/presented on top of a parent that already conforms, so walking past them is correct.
        user == nil ? .lepersColony : nil
    }
}

// MARK: - Page picker

/// A compact page-jump popover, mirroring the posts page's `Selectotron`.
private final class PagePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    private let pageCount: Int
    private let initialPage: Int
    private let onSelect: (Int) -> Void
    private let picker = UIPickerView()

    init(pageCount: Int, currentPage: Int, onSelect: @escaping (Int) -> Void) {
        self.pageCount = pageCount
        self.initialPage = currentPage
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 240, height: 240)
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

        let stack = UIStackView(arrangedSubviews: [picker, goButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { pageCount }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "\(row + 1)"
    }
}
