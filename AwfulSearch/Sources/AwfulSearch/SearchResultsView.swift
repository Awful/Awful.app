//  SearchResultsView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulExtensions
import AwfulTheming
import Combine
import SwiftUI
import UIKit

/// A page of search results.
///
/// Chrome — including the paging toolbar — lives on ``SearchResultsViewController``; see
/// ``SearchFormView`` for why.
struct SearchResultsView: View {
    @ObservedObject var model: SearchPageViewModel
    @SwiftUI.Environment(\.theme) var theme
    /// Opening a result is the view controller's job, since it depends on where this screen sits in
    /// the navigation stack.
    let onSelect: (SearchResult) -> Void

    private let topID = "top"

    var body: some View {
        Group {
            if model.isRestoring {
                restoringView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack {
                            // The search screen's message line only renders on the form, so anything that
                            // goes wrong while paging through results would otherwise be silent.
                            if !model.searchState.resultsMessage.isEmpty {
                                Text(model.searchState.resultsMessage)
                                    .font(.caption)
                                    .foregroundColor(theme[color: "unreadBadgeRedColor"] ?? theme[color: "listTextColor"])
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top)
                            }

                            if model.searchResults.isEmpty && !model.searchState.resultInfo.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Parse and display the search info with proper formatting
                                    let lines = model.searchState.resultInfo
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .components(separatedBy: .newlines)
                                        .map { $0.trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                            
                                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                        if line.starts(with: "Searched for") {
                                            Text(line)
                                                .font(.headline)
                                                .foregroundColor(theme[color: "listTextColor"])
                                                .padding(.bottom, 4)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else if line == "following criteria:" {
                                            Text(line)
                                                .font(.headline)
                                                .foregroundColor(theme[color: "listTextColor"])
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else if line.starts(with: "Text contains") || line.starts(with: "Posted by") {
                                            Text(line)
                                                .font(.body)
                                                .foregroundColor(theme[color: "listTextColor"])
                                                .padding(.vertical, 8)
                                                .padding(.leading, 16)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else if line.starts(with: "There were no results") {
                                            Text(line)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(theme[color: "listTextColor"])
                                                .padding(.top, 8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else if !line.isEmpty {
                                            Text(line)
                                                .font(.body)
                                                .foregroundColor(theme[color: "listTextColor"])
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(theme[color: "sheetBackgroundColor"] ?? Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .id(topID)
                                .padding()
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(model.searchResults) { searchResult in
                                        SearchResultCard(result: searchResult)
                                            .onTapGesture { onSelect(searchResult) }
                                    }
                                }
                                .id(topID)
                                .padding()
                            }
                        }
                        .navigationBarPlatterBackdrop()
                    }
                    .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
                    .onChange(of: model.currentPage) { _ in
                        withAnimation {
                            proxy.scrollTo(topID, anchor: .top)
                        }
                    }
                }
            }
        }
        .background((theme[color: "backgroundColor"] ?? Color(.systemBackground)).ignoresSafeArea(.all))
        .applyFontDesign(if: theme.roundedFonts)
    }

    /// Shown while a restored search's results are being fetched again, or while an immediate
    /// search (one that skipped the form) is running its first query.
    private var restoringView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(theme[color: "listSecondaryTextColor"])
            Group {
                if model.isImmediateSearch {
                    Text("Searching…", bundle: .module)
                } else {
                    Text("Loading your last search…", bundle: .module)
                }
            }
            .font(.subheadline)
            .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - SearchResult Card
struct SearchResultCard: View {
    @SwiftUI.Environment(\.theme) var theme
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            resultHeader
            resultDateTime
            resultBlurb
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(theme[color: "sheetBackgroundColor"] ?? Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .contentShape(Rectangle())
    }
    
    private var resultHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(result.resultNumber)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
            Text(result.threadTitle)
                .fontWeight(.medium)
                .foregroundColor(theme[color: "tintColor"])
        }
        .font(.subheadline)
        .lineLimit(2)
    }
    
    private var resultDateTime: some View {
        Text(result.postedDateTime)
            .font(.footnote)
            .foregroundColor(theme[color: "listSecondaryTextColor"])
    }
    
    private var resultBlurb: some View {
        var blurb = result.blurb
        blurb.foregroundColor = theme[color: "listTextColor"]
        if let tintColor = theme[color: "tintColor"] {
            for run in blurb.runs where run.inlinePresentationIntent == .stronglyEmphasized {
                blurb[run.range].foregroundColor = tintColor
            }
        }
        return Text(blurb)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct SearchResultCard_Previews: PreviewProvider {
    static let testTheme = Theme.theme(named: "brightLight") ?? Theme.defaultTheme()

    static func previewBlurb(_ before: String, highlighting hit: String, _ after: String) -> AttributedString {
        var hit = AttributedString(hit)
        hit.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(before) + hit + AttributedString(after)
    }

    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                SearchResultCard(result: SearchResult(
                    threadTitle: "Thread title blah blah blah Thread title blah blah blah",
                    resultNumber: "1.",
                    blurb: previewBlurb(
                        "This is a test blurb that shows how the card handles multiple lines of ",
                        highlighting: "text",
                        " in a more natural way"
                    ),
                    postID: "123",
                    postedDateTime: "by Someone in ForumA at Jul 1, 2023 8:04 PM"
                ))

                SearchResultCard(result: SearchResult(
                    threadTitle: "Short title",
                    resultNumber: "2.",
                    blurb: AttributedString("Short blurb"),
                    postID: "456",
                    postedDateTime: "by Someone in ForumB at Jul 2, 2023 9:04 PM"
                ))
            }
            .padding()
            .previewLayout(.sizeThatFits)
        }
        .environment(\.theme, testTheme)
    }
}
#endif

// MARK: - View controller

/// Hosts ``SearchResultsView`` as a real screen in the app's navigation stack, so the posts page a
/// result opens can be backed out of straight into these results.
///
/// Also owns the paging toolbar, mirroring `RapSheetViewController`: a bottom `UIToolbar` whose
/// items are liquid-glass pills on iOS 26 (clear bar background) and an opaque themed bar earlier.
/// The app's `NavigationController` doesn't manage a bottom toolbar — `PostsPageView` and
/// `RapSheetViewController` each carry their own — so this screen does too.
public final class SearchResultsViewController: HostingController<AnyView> {

    private let model: SearchPageViewModel
    private var cancellables: Set<AnyCancellable> = []

    // Mirrors of the model's published paging state. `@Published` emits on `willSet`, so reading
    // `model.currentPage` inside a sink returns the old value — always use the emitted values.
    private var currentPage = 1
    private var totalPages = 1
    private var isRestoring = false
    /// Guards against re-entrant page loads while one is in flight (the model has no published
    /// loading flag), mirroring `RapSheetViewController`'s `isLoading` gating.
    private var isNavigating = false

    private lazy var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
    private var toolbarBottomConstraint: NSLayoutConstraint?

    /// Keeps the paging controls from sitting flush against the bottom edge (same as `RapSheetViewController`).
    private static let toolbarBottomPadding: CGFloat = 2

    // MARK: Toolbar items

    private lazy var backItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(image: UIImage(named: "arrowleft")) { [weak self] _ in
            guard let self, self.currentPage > 1 else { return }
            self.go(to: self.currentPage - 1)
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
            guard let self, self.currentPage < self.totalPages else { return }
            self.go(to: self.currentPage + 1)
        })
        item.accessibilityLabel = "Next page"
        return item
    }()

    /// A results screen that runs `query` forum-wide immediately, skipping the search form
    /// entirely. Push it on its own — there's no form underneath, so backing out returns to
    /// wherever the search came from.
    public static func immediateSearch(query: String, handlers: SearchHandlers) -> SearchResultsViewController {
        let resultsVC = SearchResultsViewController(
            model: SearchPageViewModel(immediateQuery: query, handlers: handlers))
        // Normally inherited from the form underneath; there isn't one here, and the tab bar
        // would otherwise sit on top of the paging toolbar.
        resultsVC.hidesBottomBarWhenPushed = true
        return resultsVC
    }

    init(model: SearchPageViewModel) {
        self.model = model
        // `open` can't be referenced before super.init, so route through a box the view can call.
        let opener = ResultOpener()
        super.init(rootView: AnyView(
            SearchResultsView(model: model, onSelect: { opener.open?($0) }).themed()
        ))
        opener.open = { [weak self] in self?.open($0) }

        title = String(localized: "Search Results", bundle: .module)
    }

    @MainActor public required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        // Pinned to the view's bottom, not the safe area: the toolbar's reserved space is fed back
        // into the safe area via `additionalSafeAreaInsets`, and pinning to the safe area guide
        // would make that a feedback loop. `updateToolbarInsets()` positions it above the device's
        // own bottom inset instead.
        let bottom = toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        toolbarBottomConstraint = bottom
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom,
        ])
        toolbar.items = [.flexibleSpace(), backItem, currentPageItem, forwardItem, .flexibleSpace()]
        if #available(iOS 26.0, *) {
            // Only the real buttons: touching the flexible spaces makes them join the shared
            // glass background, merging every platter into one full-width pill.
            for item in [backItem, currentPageItem, forwardItem] {
                item.hidesSharedBackground = !LiquidGlass.isEnabled
            }
        }

        // No `.receive(on:)` needed — the model is main-actor.
        Publishers.CombineLatest3(model.$currentPage, model.$totalPages, model.$isRestoring)
            .sink { [weak self] page, total, restoring in
                guard let self else { return }
                self.currentPage = page
                self.totalPages = total
                self.isRestoring = restoring
                self.updateToolbar()
            }
            .store(in: &cancellables)

        // Re-apply the theme now that the toolbar is in the hierarchy.
        themeDidChange()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateToolbarInsets()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateToolbarInsets()
    }

    public override func themeDidChange() {
        super.themeDidChange()
        guard isViewLoaded else { return }
        toolbar.tintColor = theme["toolbarTextColor"]
        configureToolbarAppearance()
    }

    /// A clear glass bar on iOS 26 (only the liquid-glass item pills show), opaque before. A `barTintColor`
    /// (which we deliberately don't set) would force an opaque grey bar even on iOS 26. Same idiom as
    /// `RapSheetViewController`.
    private func configureToolbarAppearance() {
        let appearance = UIToolbarAppearance()
        if #available(iOS 26.0, *), LiquidGlass.isEnabled, toolbar.isTranslucent {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundImage = nil
        } else {
            // Force opaque pre-26 (and when Liquid Glass is disabled) so scrolled content doesn't bleed through the toolbar.
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

        if #available(iOS 26.0, *) {
            // iOS 26 toolbars ignore the opaque appearance (items get glass platters over a
            // transparent bar), so paint the legacy background ourselves when glass is disabled.
            toolbar.setLegacyOpaqueBackground(color: LiquidGlass.isEnabled ? nil : theme["backgroundColor"])
        }

        toolbar.setNeedsLayout()
        toolbar.layoutIfNeeded()
    }

    // MARK: Paging

    private func go(to page: Int) {
        guard !isNavigating else { return }
        isNavigating = true
        updateToolbar()
        Task {
            await model.goToPage(page: page)
            isNavigating = false
            updateToolbar()
        }
    }

    private func updateToolbar() {
        guard isViewLoaded else { return }
        // The restore path shows a full-screen spinner; a stale "1 / 1" bar over it helps no one.
        toolbar.isHidden = isRestoring
        let current = max(currentPage, 1)
        let total = max(totalPages, current)
        currentPageItem.title = "\(current) / \(total)"
        currentPageItem.accessibilityLabel = "Page \(current) of \(total)"
        currentPageItem.isEnabled = total > 1 && !isNavigating
        backItem.isEnabled = current > 1 && !isNavigating
        forwardItem.isEnabled = current < total && !isNavigating
        updateToolbarInsets()
    }

    /// Floats the toolbar above the device's own bottom inset and reserves matching safe-area space
    /// so the hosted `ScrollView` insets its content clear of the bar while still drawing behind it.
    private func updateToolbarInsets() {
        guard isViewLoaded else { return }
        let toolbarHeight = toolbar.frame.height > 0 ? toolbar.frame.height : 44
        let reserved = toolbar.isHidden ? 0 : toolbarHeight + Self.toolbarBottomPadding
        // Subtract our own contribution to get the device's base inset; otherwise the toolbar would
        // climb its own reserved space.
        let baseBottomInset = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        toolbarBottomConstraint?.constant = -(baseBottomInset + Self.toolbarBottomPadding)
        if additionalSafeAreaInsets.bottom != reserved {
            additionalSafeAreaInsets.bottom = reserved
        }
    }

    private func showPagePicker(from item: UIBarButtonItem?) {
        guard totalPages > 1, !isNavigating else { return }
        let picker = PagePickerViewController(
            pageCount: totalPages,
            currentPage: max(currentPage, 1),
            onSelect: { [weak self] selected in
                guard let self, selected != self.currentPage else { return }
                self.go(to: selected)
            }
        )
        picker.popoverPresentationController?.barButtonItem = item
        present(picker, animated: true)
    }

    private func open(_ result: SearchResult) {
        Task { @MainActor in
            await model.handlers.openPost(result.postID, self)
        }
    }
}

/// Lets the hosted view call back into its view controller, which doesn't exist yet when the view
/// is built in `init`.
private final class ResultOpener {
    var open: ((SearchResult) -> Void)?
}
