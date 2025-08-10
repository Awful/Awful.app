//  SearchView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import SwiftUI
import HTMLReader
import AwfulCore
import AwfulTheming

struct SearchResultsView: View {
    @ObservedObject var model: SearchPageViewModel
    @SwiftUI.Environment(\.dismiss) var dismiss
    @SwiftUI.Environment(\.theme) var theme
    
    private let topID = "top"
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
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
                        .background(theme[color: "sheetBackgroundColor"]!)
                        .cornerRadius(12)
                        .id(topID)
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(model.searchResults) { searchResult in
                                SearchResultCard(result: searchResult)
                                    .onTapGesture {
                                        model.viewState = .none
                                        AppDelegate.instance.open(route: .post(id: searchResult.postID, .noseen))
                                    }
                            }
                        }
                        .id(topID)
                        .padding()
                    }
                }
                .background(theme[color: "backgroundColor"]!)
                .onChange(of: model.currentPage) { _ in
                    withAnimation {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Search Results")
                        .font(.headline)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Back") {
                        model.viewState = .search
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        model.viewState = .none
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                
                ToolbarItem(placement: .bottomBar) {
                    paginationControls
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .tint(theme[color: "tintColor"])
    }
    
    private var paginationControls: some View {
        HStack {
            Button(action: {
                Task {
                    await model.goToPage(page: model.currentPage - 1)
                }
            }) {
                Image(systemName: "arrow.left")
                    .foregroundColor(model.currentPage <= 1 ? theme[color: "placeholderTextColor"] : theme[color: "tintColor"])
            }
            .disabled(model.currentPage <= 1)
            
            Spacer()
            
            Text("\(model.currentPage) of \(model.totalPages)")
                .font(.headline)
                .foregroundColor(theme[color: "listTextColor"])
                .frame(minWidth: 80)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                Task {
                    await model.goToPage(page: model.currentPage + 1)
                }
            }) {
                Image(systemName: "arrow.right")
                    .foregroundColor(model.currentPage >= model.totalPages ? theme[color: "placeholderTextColor"] : theme[color: "tintColor"])
            }
            .disabled(model.currentPage >= model.totalPages)
        }
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
        .background(theme[color: "sheetBackgroundColor"]!)
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
        let blurbWithMarkdown = result.blurb
            .replacingOccurrences(of: "<em>", with: "**", options: .caseInsensitive)
            .replacingOccurrences(of: "</em>", with: "**", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let text: Text
        if var attributedString = try? AttributedString(markdown: blurbWithMarkdown) {
            attributedString.foregroundColor = theme[color: "listTextColor"]
            for run in attributedString.runs where run.inlinePresentationIntent == .stronglyEmphasized {
                if let tintColor = theme[color: "tintColor"] {
                    attributedString[run.range].foregroundColor = tintColor
                }
            }
            text = Text(attributedString)
        } else {
            text = Text(blurbWithMarkdown)
                .foregroundColor(theme[color: "listTextColor"])
        }
        
        return text
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview Provider
struct SearchResultCard_Previews: PreviewProvider {
    static let testTheme = Theme.theme(named: "brightLight") ?? Theme.defaultTheme()
    
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                SearchResultCard(result: SearchResult(
                    threadTitle: "Thread title blah blah blah Thread title blah blah blah",
                    resultNumber: "1.",
                    blurb: "This is a test blurb that shows how the card handles multiple lines of text in a more natural way",
                    forumTitle: "Test Forum",
                    postID: "123",
                    userName: "TestUser",
                    postedDateTime: "by Someone in ForumA at Jul 1, 2023 8:04 PM"
                ))
                
                SearchResultCard(result: SearchResult(
                    threadTitle: "Short title",
                    resultNumber: "2.",
                    blurb: "Short blurb",
                    forumTitle: "Another Forum",
                    postID: "456",
                    userName: "AnotherUser",
                    postedDateTime: "by Someone in ForumB at Jul 2, 2023 9:04 PM"
                ))
            }
            .padding()
            .previewLayout(.sizeThatFits)
        }
        .environment(\.theme, testTheme)
    }
}

struct SearchView: View {
    @ObservedObject private var model: SearchPageViewModel
    @SwiftUI.Environment(\.theme) var theme
    @SwiftUI.Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    init(model: SearchPageViewModel) {
        self.model = model
    }
    
    var body: some View {
        Group {
            switch model.viewState {
            case .search:
                NavigationView {
                    VStack(spacing: 0) {
                        // Search and help section
                        VStack(alignment: .leading, spacing: 12) {
                            searchField
                            searchHelp
                        }
                        .padding()
                        .background(theme[color: "sheetBackgroundColor"])
                        
                        forumSelectionList
                            .padding(.horizontal)
                    }
                    .background(theme[color: "backgroundColor"]!.ignoresSafeArea(.all))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFieldFocused = false
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Search Forums")
                                .font(.headline)
                                .foregroundColor(theme[color: "navigationBarTextColor"])
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Exit") {
                                model.viewState = .none
                            }
                            .foregroundColor(theme[color: "navigationBarTextColor"])
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Search") {
                                Task {
                                    await model.performSearch()
                                }
                            }
                            .disabled(model.searchState.query.isEmpty)
                            .foregroundColor(theme[color: "navigationBarTextColor"])
                        }
                    }
                    .background(NavigationConfigurator(theme: theme))
                }
                .navigationViewStyle(.stack)
                .tint(theme[color: "tintColor"])
            
            case .results:
                SearchResultsView(model: model)
            
            case .none:
                EmptyView()
            }
        }
        .applyFontDesign(if: theme.roundedFonts)
        .interactiveDismissDisabled()
        .onChange(of: model.viewState) { newState in
            if newState == .none {
                model.clearHeavyObjects()
                dismiss()
            }
        }
        .onDisappear {
            // Ensure cleanup happens when view disappears
            model.clearHeavyObjects()
        }
    }
    
    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
                
                ZStack(alignment: .leading) {
                    if model.searchState.query.isEmpty {
                        Text("Search forums...")
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
            .background(theme[color: "backgroundColor"]!)
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
            Text("Example searches:")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme[color: "listSecondaryTextColor"])
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.searchHelpHints) { hint in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(hint.text)
                            .font(.footnote)
                            .foregroundStyle(theme[color: "listSecondaryTextColor"]!)
                    }
                }
            }
        }
        .padding(12)
        .background(theme[color: "backgroundColor"]!)
        .cornerRadius(8)
    }
    
    private var forumSelectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Select Forums")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(theme[color: "listTextColor"])
                    Spacer()
                    Toggle(isOn: model.allForumsBinding) {
                        Text("Toggle All")
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

struct NavigationConfigurator: UIViewControllerRepresentable {
    let theme: Theme
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let navigationController = uiViewController.navigationController {
                // Configure navigation bar
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithOpaqueBackground()
                navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"]
                navAppearance.shadowColor = .clear

                // Ensure the custom back indicator image from assets is used
                if let backImage = UIImage(named: "back") {
                    navAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
                }
                
                let textColor = theme[uicolor: "navigationBarTextColor"]!
                navAppearance.titleTextAttributes = [.foregroundColor: textColor]

                // Ensure text-based bar button items adopt theme font (rounded if enabled)
                let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
                let buttonAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: textColor,
                    .font: buttonFont
                ]
                navAppearance.buttonAppearance.normal.titleTextAttributes = buttonAttrs
                navAppearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttrs
                navAppearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttrs
                navAppearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttrs
                navAppearance.backButtonAppearance.normal.titleTextAttributes = buttonAttrs
                navAppearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttrs
                
                navigationController.navigationBar.standardAppearance = navAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navAppearance
                // Drive the bar style from the current theme so status bar
                // icons match the theme while Search is presented.
                let isLightBackground = (theme["statusBarBackground"] == "light")
                navigationController.navigationBar.barStyle = isLightBackground ? .default : .black
                
                // Configure toolbar
                let toolbarAppearance = UIToolbarAppearance()
                toolbarAppearance.configureWithOpaqueBackground()
                toolbarAppearance.backgroundColor = theme[uicolor: "tabBarBackgroundColor"]
                toolbarAppearance.shadowColor = .clear
                
                navigationController.toolbar.standardAppearance = toolbarAppearance
                navigationController.toolbar.compactAppearance = toolbarAppearance
                if #available(iOS 15.0, *) {
                    navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
                    navigationController.toolbar.compactScrollEdgeAppearance = toolbarAppearance
                }
                
                // Force immediate update
                navigationController.toolbar.setNeedsLayout()
            }
        }
    }
}

// MARK: - Preview Provider
struct SearchView_Previews: PreviewProvider {
    static let previewSearchHTML = """
    <form action="query.php" method="post" accept-charset="UTF-8">
    <div class="search_container">
        <div class="search_form standard">
            <h1>Search the forums<span class="beta">BETA</span></h1>
            <input name="q" type="text" id="query" value="" autofocus /><br />
            <button type="submit" name="action" value="query">Search</button><br />
        </div>
        <div class="search_help">
            <div class="title">Example Searches</div>
            <div class="term">intitle:"example search" username:"user"</div>
            <div class="term">"quoted phrase" since:"last week"</div>
            <div style="margin-top:16px; font-weight: bold">Preview mode - search functionality available</div>
        </div>
        <div class="clearfix forumlist_container standard">
            <div class="forumlist">
                <button type="button" data-forumid="-1" class="search_forum depth0">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="-1">
                    Select All Forums
                </button>
                <div data-forumid="48" class="search_forum depth0">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="48">
                    Forum 1
                </div>
                <div data-forumid="273" class="search_forum depth1 parent48">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="273">
                    Subforum 1
                </div>
                <div data-forumid="51" class="search_forum depth0">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="51">
                    Forum 2
                </div>
                <div data-forumid="44" class="search_forum depth1 parent51">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="44">
                    Subforum 2
                </div>
                <div data-forumid="152" class="search_forum depth0">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="152">
                    Forum 3
                </div>
                <div data-forumid="151" class="search_forum depth1 parent152">
                    <input type="checkbox" class="forumcheck" name="forums[]" value="151">
                    Subforum 3
                </div>
            </div>
        </div>
    </div>
    </form>
    """
    
    static var previews: some View {
        let previewModel = SearchPageViewModel(
            forumSelectOptions: [
                ForumSelectOption(optionText: "Main Forum", value: "1"),
                ForumSelectOption(optionText: "Sub Forum", value: "2", depth: 1, parentIDs: ["1"]),
                ForumSelectOption(optionText: "Another Forum", value: "3")
            ],
            searchHelpHints: [
                SearchHelpHint(text: "Search by title: intitle:\"example\""),
                SearchHelpHint(text: "Search by user: username:\"example\"")
            ],
            isPreview: true,
            previewHTML: previewSearchHTML
        )
        
        SearchView(model: previewModel)
            .environment(\.theme, Theme.theme(named: "brightLight") ?? Theme.defaultTheme())
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
                .foregroundColor(configuration.isOn ? theme[color: "tintColor"]! : isEnabled ? theme[color: "listTextColor"]! : theme[color: "placeholderTextColor"]!)
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
                           

// MARK: - View Models
@MainActor
final class SearchPageViewModel: ObservableObject {
    @Published private(set) var searchPageHtmlDoc: HTMLDocument = HTMLDocument(string: "")  // Initialize with empty document
    @Published private(set) var searchResultsHtmlDoc: HTMLDocument?
    @Published var searchState = SearchState()
    @Published var forumSelectOptions: [ForumSelectOption]
    @Published private(set) var searchResults: [SearchResult]
    @Published private(set) var searchHelpHints: [SearchHelpHint]
    @Published var viewState: SearchViewState = .search
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var totalPages: Int = 1
    
    private let isPreview: Bool
    private var searchQueryID: String?
    private let previewHTML: String?
    
    init(
        forumSelectOptions: [ForumSelectOption] = [],
        searchHelpHints: [SearchHelpHint] = [],
        searchResults: [SearchResult] = [],
        isPreview: Bool = false,
        previewHTML: String? = nil
    ) {
        self.forumSelectOptions = forumSelectOptions
        self.searchHelpHints = searchHelpHints
        self.searchResults = searchResults
        self.isPreview = isPreview
        self.previewHTML = previewHTML
        
        // Move the Task creation to after initialization
        Task { [weak self] in
            await self?.loadInitialData()
        }
    }
    
    var allForumsBinding: Binding<Bool> {
        Binding<Bool>(
            get: { !self.forumSelectOptions.isEmpty && self.forumSelectOptions.allSatisfy(\.isSelected) },
            set: { newValue in
                guard newValue != self.forumSelectOptions.allSatisfy(\.isSelected) else { return }
                for i in self.forumSelectOptions.indices {
                    self.forumSelectOptions[i].isSelected = newValue
                }
            }
        )
    }
    
    private func loadInitialData() async {
        await fetchAndParseSearchPage()
    }
    
    func fetchAndParseSearchPage() async {
        let htmlString: String
        
        if isPreview {
            // Use preview HTML for previews
            print("🔍 SearchView: Using preview HTML")
            if let previewHTML = previewHTML, !previewHTML.isEmpty {
                htmlString = previewHTML
                print("✅ SearchView: Successfully loaded preview HTML")
            } else {
                print("❌ SearchView: No preview HTML provided, using minimal fallback")
                htmlString = """
                <form action="query.php" method="post" accept-charset="UTF-8">
                <div class="search_help">
                    <div class="title">Example Searches</div>
                    <div class="term">Search functionality available in preview mode</div>
                </div>
                <div class="clearfix forumlist_container standard">
                    <div class="forumlist">
                        <div data-forumid="48" class="search_forum depth0">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="48">
                            Main
                        </div>
                        <div data-forumid="51" class="search_forum depth0">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="51">
                            Discussion
                        </div>
                    </div>
                </div>
                </form>
                """
            }
        } else {
            // Fetch dynamically from server for real app
            do {
                let document = try await ForumsClient.shared.fetchSearchPage()
                htmlString = document.innerHTML
            } catch {
                print("❌ SearchView: Failed to fetch search page: \(error)")
                searchState.message = "Failed to load search page: \(error.localizedDescription)"
                return
            }
        }
        
        searchPageHtmlDoc = HTMLDocument(string: htmlString)
        await scrapeForumSelectOptions()
    }
    
    func scrapeForumSelectOptions() async {
        if let forumListHtmlDoc = searchPageHtmlDoc.firstNode(matchingSelector: "form[action='query.php']") {
            // Extract search message
            searchState.message = forumListHtmlDoc.firstNode(matchingSelector: ".search_message")?.textContent ?? ""
            
            // Extract help hints
            if let searchHelpText = forumListHtmlDoc.firstNode(matchingSelector: ".search_help") {
                searchHelpHints = searchHelpText.nodes(matchingSelector: ".term").map { node in
                    SearchHelpHint(text: node.textContent)
                }
            }
            
            // Extract forum options
            forumSelectOptions = forumListHtmlDoc.nodes(matchingSelector: ".search_forum")
                .compactMap { div -> ForumSelectOption? in
                    guard let input = div.firstNode(matchingSelector: ".forumcheck"),
                          let value = input["value"],
                          let text = div.textContent.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines),
                          text != "Select All Forums",
                          !text.isEmpty
                    else { return nil }
                    
                    let classAttribute = div["class"] ?? ""
                    let classes = classAttribute.components(separatedBy: .whitespaces)

                    let depth = classes.first(where: { $0.hasPrefix("depth") })
                        .flatMap { Int($0.dropFirst("depth".count)) } ?? 0

                    let parentIDs = classes.filter { $0.hasPrefix("parent") }
                        .map { String($0.dropFirst("parent".count)) }
                    
                    return ForumSelectOption(
                        optionText: text,
                        value: value,
                        isSelected: input["checked"] != nil,
                        depth: depth,
                        parentIDs: parentIDs
                    )
                }
        }
    }
    
    func scrapeForumResultsPage(requestedPage: Int? = nil) async {
        if let resultHtmlDoc = searchResultsHtmlDoc {
            searchState.resultInfo = resultHtmlDoc.firstNode(matchingSelector: "#search_info")?.textContent ?? ""
            
            searchResults = resultHtmlDoc.nodes(matchingSelector: ".search_result").map { searchResult in
                let blurbNode: HTMLNode? = searchResult.firstNode(matchingSelector: ".blurb")
                let blurb: String
                if let element = blurbNode as? HTMLElement {
                    blurb = element.innerHTML
                } else {
                    blurb = blurbNode?.textContent ?? ""
                }
                return SearchResult(
                    threadTitle: searchResult.firstNode(matchingSelector: ".threadtitle")?.textContent ?? "",
                    resultNumber: searchResult.firstNode(matchingSelector: ".result_number")?.textContent ?? "",
                    blurb: blurb,
                    forumTitle: searchResult.firstNode(matchingSelector: ".forumtitle")?.textContent ?? "",
                    postID: searchResult.firstNode(matchingSelector: ".threadtitle")?["href"]
                        .flatMap { URLComponents(string: $0) }?
                        .queryItems?
                        .first { $0.name == "postid" }?
                        .value ?? "",
                    userName: searchResult.firstNode(matchingSelector: ".username")?.textContent ?? "",
                    postedDateTime: searchResult.firstNode(matchingSelector: ".hit_info")?.textContent ?? ""
                )
            }
            
            if let pagesDiv = resultHtmlDoc.firstNode(matchingSelector: ".pages") {
                if let currentPageNode = pagesDiv.firstNode(matchingSelector: "b") {
                    self.currentPage = Int(currentPageNode.textContent.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                } else if let requestedPage = requestedPage {
                    self.currentPage = requestedPage
                }
                
                let pageLinks = pagesDiv.nodes(matchingSelector: "a")
                var maxPage = currentPage

                if self.searchQueryID == nil,
                   let firstLink = pageLinks.first,
                   let href = firstLink["href"],
                   let url = URL(string: href, relativeTo: ForumsClient.shared.baseURL),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let qidItem = components.queryItems?.first(where: { $0.name == "qid" }) {
                    self.searchQueryID = qidItem.value
                }

                for link in pageLinks {
                    guard let href = link["href"],
                          let url = URL(string: href, relativeTo: ForumsClient.shared.baseURL),
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                          let pageItem = components.queryItems?.first(where: { $0.name == "page" }),
                          let pageValue = pageItem.value,
                          let pageNumber = Int(pageValue) else { continue }
                    
                    if pageNumber > maxPage {
                        maxPage = pageNumber
                    }
                }
                self.totalPages = maxPage
            } else if let requestedPage = requestedPage {
                self.currentPage = requestedPage
                // Preserve totalPages if it was already set and we're just navigating
                // Only reset to 1 if it was never set (still at initial value)
                if self.totalPages == 1 && requestedPage > 1 {
                    // If we're on page > 1 but totalPages is still 1,
                    // we know there must be at least requestedPage pages
                    self.totalPages = requestedPage
                }
            }
        }
    }
    
    func toggleForumSelection(for option: ForumSelectOption) {
        guard let index = forumSelectOptions.firstIndex(where: { $0.id == option.id }) else { return }

        let isSelected = !forumSelectOptions[index].isSelected
        forumSelectOptions[index].isSelected = isSelected

        // Find all children and update their selection state
        for i in forumSelectOptions.indices {
            if forumSelectOptions[i].parentIDs.contains(option.id) {
                forumSelectOptions[i].isSelected = isSelected
            }
        }
    }
    
    func performSearch() async {
        searchState.message = ""
        
        let forumIDs = forumSelectOptions
            .filter(\.isSelected)
            .map(\.value)
        
        do {
            let document = try await ForumsClient.shared.searchForums(
                query: searchState.query,
                forumIDs: forumIDs
            )
            
            searchResultsHtmlDoc = document
            viewState = .results
            
            // Reset pagination state before scraping new search results
            self.currentPage = 1
            self.totalPages = 1
            self.searchQueryID = nil
            
            await scrapeForumResultsPage()
            
        } catch {
            searchState.message = "Search failed: \(error.localizedDescription)"
            print("Search error: \(error)")
        }
    }
    
    func goToPage(page: Int) async {
        guard let qid = searchQueryID else {
            searchState.message = "Cannot navigate to page, no query ID."
            return
        }
        
        do {
            let document = try await ForumsClient.shared.searchForumsPage(
                queryID: qid,
                page: page
            )
            
            searchResultsHtmlDoc = document
            await scrapeForumResultsPage(requestedPage: page)
            
        } catch {
            searchState.message = "Failed to load page: \(error.localizedDescription)"
            print("Page load error: \(error)")
        }
    }
    
    func clearHeavyObjects() {
        searchPageHtmlDoc = HTMLDocument(string: "")
        searchResultsHtmlDoc = nil
        searchResults.removeAll()
        forumSelectOptions.removeAll()
        searchHelpHints.removeAll()
        searchQueryID = nil
        searchState = SearchState()
    }
}

// MARK: - Models
struct ForumSelectOption: Identifiable, Equatable {
    var id: String { value }
    var optionText: String
    var value: String
    var isSelected: Bool = false
    var depth: Int = 0
    var parentIDs: [String] = []
}

struct SearchResult: Identifiable, Equatable {
    var id: String { postID }
    let threadTitle: String
    let resultNumber: String
    let blurb: String
    let forumTitle: String
    let postID: String
    let userName: String
    let postedDateTime: String
    var highlight: String = ""
}

struct SearchHelpHint: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct SearchState {
    var query: String = ""
    var message: String = ""
    var resultInfo: String = ""
}

enum SearchViewState {
    case search, results, none
}

extension Int {
    var isSuccessful: Bool { self == 200 || self == 302 }
}

// MARK: - Custom Hosting Controller
final class SearchHostingController: UIHostingController<SearchView> {
    // Strong reference to keep the view model alive
    private let searchModel: SearchPageViewModel
    
    init() {
        self.searchModel = SearchPageViewModel()
        super.init(rootView: SearchView(model: searchModel))
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure this controller controls status bar appearance so it stays
        // consistent with the app's theme while presented
        modalPresentationCapturesStatusBarAppearance = true
    }

    // Keep status bar style in sync with the current theme so opening the
    // search view does not change it unexpectedly.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = Theme.defaultTheme()
        return (theme["statusBarBackground"] == "light") ? .darkContent : .lightContent
    }

    // Force the system to use this hosting controller's status bar style
    // instead of deferring to the child SwiftUI navigation controller.
    override var childForStatusBarStyle: UIViewController? { nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
}

