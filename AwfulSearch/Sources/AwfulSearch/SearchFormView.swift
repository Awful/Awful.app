//  SearchFormView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulExtensions
import AwfulTheming
import Combine
import SwiftUI
import UIKit

/// The search form: what to search for, and (forum-wide searches only) which forums to look in.
///
/// Chrome lives on SearchFormViewController rather than in a SwiftUI `.toolbar`, because these
/// screens are pushed onto the app's own `NavigationController` and toolbar bridging needs iOS 16.
struct SearchFormView: View {
    @ObservedObject var model: SearchPageViewModel
    @SwiftUI.Environment(\.theme) var theme
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search and help section
            VStack(alignment: .leading, spacing: 12) {
                searchField
                searchHelp
            }
            .padding()
            .background(theme[color: "sheetBackgroundColor"])

            if model.threadID == nil {
                forumSelectionList
                    .padding(.horizontal)
            } else {
                Spacer()
            }
        }
        .background((theme[color: "backgroundColor"] ?? Color(.systemBackground)).ignoresSafeArea(.all))
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
        }
        .applyFontDesign(if: theme.roundedFonts)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
                
                ZStack(alignment: .leading) {
                    if model.searchState.query.isEmpty {
                        Text(model.threadID == nil ? "Search forums..." : "Search thread...", bundle: .module)
                            .foregroundColor(theme[color: "listSecondaryTextColor"])
                    }
                    
                    TextField("", text: $model.searchState.query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .foregroundColor(theme[color: "listTextColor"])
                        .tint(theme[color: "tintColor"])
                        .onSubmit {
                            if !model.searchState.query.isEmpty {
                                Task {
                                    await model.performSearch()
                                }
                            }
                        }
                }
                
                if !model.searchState.query.isEmpty {
                    Button(action: { model.searchState.query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme[color: "listSecondaryTextColor"])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
            .cornerRadius(8)
            
            if !model.searchState.message.isEmpty {
                Text(model.searchState.message)
                    .foregroundColor(theme[color: "unreadBadgeRedColor"])
                    .font(.caption)
            }
        }
    }
    
    private var searchHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example searches:", bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme[color: "listSecondaryTextColor"])
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.searchHelpHints) { hint in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(hint.text)
                            .font(.footnote)
                            .foregroundStyle(theme[color: "listSecondaryTextColor"] ?? Color(.secondaryLabel))
                    }
                }
            }
        }
        .padding(12)
        .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var forumSelectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Select Forums", bundle: .module)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(theme[color: "listTextColor"])
                    Spacer()
                    Toggle(isOn: model.allForumsBinding) {
                        Text("Toggle All", bundle: .module)
                            .font(.body)
                            .foregroundColor(theme[color: "tintColor"])
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach($model.forumSelectOptions) { $option in
                        Toggle(
                            isOn: Binding(
                                get: { $option.wrappedValue.isSelected },
                                set: { _ in model.toggleForumSelection(for: $option.wrappedValue) }
                            )
                        ) {
                            Text($option.wrappedValue.optionText)
                                .lineLimit(1)
                                .foregroundColor(theme[color: "listTextColor"])
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        .padding(.leading, CGFloat($option.wrappedValue.depth) * 20)
                    }
                }
            }
            .padding()
        }
    }
}

// thanks to https://swiftwithmajid.com/2020/03/04/customizing-toggle-in-swiftui/
struct CheckboxToggleStyle: ToggleStyle {
    @SwiftUI.Environment(\.isEnabled) var isEnabled
    @SwiftUI.Environment(\.theme) var theme
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundColor(configuration.isOn ? (theme[color: "tintColor"] ?? Color.accentColor) : isEnabled ? (theme[color: "listTextColor"] ?? Color(.label)) : (theme[color: "placeholderTextColor"] ?? Color(.placeholderText)))
        }
        .font(.body)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                configuration.isOn.toggle()
            }
        }
    }
}

// MARK: - View controller

/// Hosts ``SearchFormView`` as a real screen in the app's navigation stack.
///
/// Owns the ``SearchPageViewModel`` and drives the flow: running a search pushes
/// ``SearchResultsViewController`` on top of this, and a failed restore pops back down to here.
public final class SearchFormViewController: HostingController<AnyView> {

    let model: SearchPageViewModel
    private var cancellables: Set<AnyCancellable> = []
    /// A message that arrived before there was anywhere to show it. See `viewDidAppear`.
    private var pendingBannerMessage: String?

    /// `.plain` rather than `.done`: on iOS 26 a `.done` item renders as a filled, tinted capsule,
    /// which doesn't match the plain glass buttons everywhere else in the app.
    ///
    /// Shows the same `quick-look` icon as the Forums list's Search button. That asset lives in the
    /// app's main bundle rather than this package, so fall back to a "Search" title when it's
    /// unavailable (e.g. package-only previews).
    private lazy var searchItem: UIBarButtonItem = {
        let item: UIBarButtonItem
        if let icon = UIImage(named: "quick-look") {
            item = UIBarButtonItem(image: icon, style: .plain, target: self, action: #selector(didTapSearch))
        } else {
            item = UIBarButtonItem(
                title: String(localized: "Search", bundle: .module),
                style: .plain, target: self, action: #selector(didTapSearch))
        }
        item.accessibilityLabel = String(localized: "Search", bundle: .module)
        return item
    }()

    /// - Parameter restoring: when set, the model goes straight to fetching these results. Pair it
    ///   with ``makeStack(threadID:restoring:handlers:)`` so the results screen is pushed to receive them.
    public init(
        threadID: String? = nil,
        restoring: LastSearchStore.Record? = nil,
        handlers: SearchHandlers
    ) {
        model = SearchPageViewModel(threadID: threadID, restoring: restoring, handlers: handlers)
        super.init(rootView: AnyView(SearchFormView(model: model).themed()))

        title = model.threadID == nil
            ? String(localized: "Search Forums", bundle: .module)
            : String(localized: "Search Thread", bundle: .module)
        // Keeps the tab bar out from under the results screen's pagination controls, and out from
        // under the posts page that opening a result pushes.
        hidesBottomBarWhenPushed = true

        model.onResultsReady = { [weak self] in self?.showResults() }
        model.onRestoreFailed = { [weak self] message in self?.returnToForm(bannering: message) }
    }

    @MainActor public required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The screens to push for a search, root first.
    ///
    /// A restorable last search comes back with its results already on top, so backing out of them
    /// lands on the form rather than leaving search altogether.
    public static func makeStack(
        threadID: String? = nil,
        restoring: LastSearchStore.Record? = nil,
        handlers: SearchHandlers
    ) -> [UIViewController] {
        let form = SearchFormViewController(threadID: threadID, restoring: restoring, handlers: handlers)
        guard restoring != nil else { return [form] }
        return [form, SearchResultsViewController(model: form.model)]
    }

    /// Pushes a stack from ``makeStack(threadID:restoring:handlers:)`` as a single animated transition.
    ///
    /// Splicing rather than pushing twice keeps the restored results' arrival to one animation while
    /// still leaving the form underneath them.
    public static func push(_ screens: [UIViewController], onto navigationController: UINavigationController) {
        if screens.count == 1 {
            navigationController.pushViewController(screens[0], animated: true)
        } else {
            navigationController.setViewControllers(
                navigationController.viewControllers + screens, animated: true)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = searchItem

        model.$searchState
            .map { !$0.query.isEmpty }
            .removeDuplicates()
            .assign(to: \.isEnabled, on: searchItem)
            .store(in: &cancellables)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let pendingBannerMessage {
            self.pendingBannerMessage = nil
            showBanner(pendingBannerMessage)
        }
    }

    @objc private func didTapSearch() {
        Task { await model.performSearch() }
    }

    /// Pushes the results screen, unless it's already up — a restore puts it there before the model
    /// has anything to report.
    private func showResults() {
        guard let navigationController,
              !(navigationController.topViewController is SearchResultsViewController)
        else { return }
        navigationController.pushViewController(SearchResultsViewController(model: model), animated: true)
    }

    /// Comes back from a dead restore, explaining why.
    private func returnToForm(bannering message: String) {
        if let navigationController, navigationController.topViewController !== self,
           navigationController.viewControllers.contains(self)
        {
            navigationController.popToViewController(self, animated: true)
        }
        showBanner(message)
    }

    /// Shows a plain informational toast, holding onto it if this screen isn't on show yet.
    ///
    /// A restore can outrun the push animation, and a banner added to a view that isn't on screen
    /// yet auto-dismisses before anyone sees it.
    private func showBanner(_ message: String) {
        guard isViewLoaded, view.window != nil else {
            pendingBannerMessage = message
            return
        }
        BannerToastView.show(in: view, theme: theme, message: message)
    }
}
