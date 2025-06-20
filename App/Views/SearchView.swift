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
                    if model.totalPages > 1 {
                        paginationControls
                    }
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
            
            Text("Page \(model.currentPage) of \(model.totalPages)")
                .font(.headline)
                .foregroundColor(theme[color: "listTextColor"])
            
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
    @StateObject private var model: SearchPageViewModel
    @SwiftUI.Environment(\.theme) var theme
    @SwiftUI.Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    init() {
        _model = StateObject(wrappedValue: SearchPageViewModel())
    }
    
    // Preview-only initializer
    init(previewModel: SearchPageViewModel) {
        _model = StateObject(wrappedValue: previewModel)
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
                
                let textColor = theme[uicolor: "navigationBarTextColor"]!
                navAppearance.titleTextAttributes = [.foregroundColor: textColor]
                
                navigationController.navigationBar.standardAppearance = navAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navAppearance
                
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
    static var previews: some View {
        SearchView(previewModel: SearchPageViewModel(
            forumSelectOptions: [
                ForumSelectOption(optionText: "Main Forum", value: "1"),
                ForumSelectOption(optionText: "Sub Forum", value: "2", depth: 1, parentIDs: ["1"]),
                ForumSelectOption(optionText: "Another Forum", value: "3")
            ],
            searchHelpHints: [
                SearchHelpHint(text: "Search by title: intitle:\"example\""),
                SearchHelpHint(text: "Search by user: username:\"example\"")
            ]
        ))
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

// MARK: - Constants
private let defaultSearchPageHTMLString =  """
                            <form action="query.php" method="post" accept-charset="UTF-8">
                            <div class="search_container">
                            <div class="search_message standard">
                            </div>
                            <div class="search_form standard">
                            <h1>Search the forums<span class="beta">BETA</span></h1>
                            <input name="q" type="text" id="query" value="threadid:3495489 quoting:&quot;Jeffrey of YOSPOS&quot; username:&quot;Poor Jesus&quot; boat" autofocus /><br />
                            <button type="submit" name="action" value="query">Search</button><br />
                            </div>
                            <div class="search_help">
                            <div class="title">Example Searches</div>
                            <div class="term">intitle:"dog breath" userid:75630 blund</div>
                            <div class="term">"gaming crimes" since:"last monday" before:"2 days ago"</div>
                            <div class="term">threadid:3858657 quoting:"Jeffrey of YOSPOS" username:"Teen Jesus" sand</div>
                            <div style="margin-top:16px; font-weight: bold">Notice: We are still fine tuning the search engine to serve you better! Try simple queries or constrain your search to a particular forum.</div>
                            <div style="margin-top:16px; font-weight: bold">Tip: Click or tap on a forum or category name to toggle the checkboxes for all of its subforums!</div>
                            </div>
                            <div class="clearfix forumlist_container standard">
                            <div class="forumlist">
                            <button type="button" data-forumid="-1" class="search_forum depth0">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="-1">
                            Select All Forums
                            </button>
                            <div data-forumid="48" class="search_forum depth0  ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="48">
                            Main
                            </div>
                            <div data-forumid="272" class="search_forum depth1  parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="272">
                            The Great Outdoors
                            </div>
                            <div data-forumid="273" class="search_forum depth1  parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="273">
                            General Bullshit
                            </div>
                            <div data-forumid="669" class="search_forum depth2  parent273 parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="669">
                            Fuck You and Dine
                            </div>
                            <div data-forumid="155" class="search_forum depth2  parent273 parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="155">
                            SA's Front Page Discussion
                            </div>
                            <div data-forumid="214" class="search_forum depth2  parent273 parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="214">
                            Everyone's/Neurotic
                            </div>
                             <div data-forumid="26" class="search_forum depth1  parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="26">
                            FYAD
                            </div>
                            <div data-forumid="167" class="search_forum depth1  parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="167">
                            Post Your Favorite/Request
                            </div>
                            <div data-forumid="670" class="search_forum depth2  parent167 parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="670">
                            Post My Favorites
                            </div>
                            <div data-forumid="268" class="search_forum depth1  parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="268">
                            BYOB
                            </div>
                            <div data-forumid="196" class="search_forum depth2  parent268 parent48 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="196">
                            Cool Crew Chat Central
                            </div>
                            <div data-forumid="51" class="search_forum depth0  ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="51">
                            Discussion
                            </div>
                            <div data-forumid="44" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="44">
                            Video Games
                            </div>
                            <div data-forumid="191" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="191">
                            Let's Play!
                            </div>
                            <div data-forumid="146" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="146">
                            WoW: Goon Squad
                            </div>
                            <div data-forumid="145" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="145">
                            The MMO HMO
                            </div>
                            <div data-forumid="279" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="279">
                            Mobile Gaming
                            </div>
                            <div data-forumid="278" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="278">
                            Retro Games
                            </div>
                            <div data-forumid="93" class="search_forum depth2  parent44 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="93">
                            Private Game Servers
                            </div>
                            <div data-forumid="234" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="234">
                            Traditional Games
                            </div>
                            <div data-forumid="103" class="search_forum depth2  parent234 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="103">
                            The Game Room
                            </div>
                            <div data-forumid="46" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="46">
                            Debate &amp; Discussion
                            </div>
                            <div data-forumid="269" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="269">
                            C-SPAM
                            </div>
                             <div data-forumid="158" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="158">
                            Ask/Tell
                            </div>
                            <div data-forumid="162" class="search_forum depth2  parent158 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="162">
                            Science, Academics and Languages
                            </div>
                            <div data-forumid="211" class="search_forum depth2  parent158 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="211">
                            Tourism &amp; Travel
                            </div>
                            <div data-forumid="200" class="search_forum depth2  parent158 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="200">
                            Business, Finance, and Careers
                            </div>
                            <div data-forumid="22" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="22">
                            Serious Hardware/Software Crap
                            </div>
                            <div data-forumid="170" class="search_forum depth2  parent22 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="170">
                            Haus of Tech Support
                            </div>
                            <div data-forumid="202" class="search_forum depth2  parent22 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="202">
                            The Cavern of COBOL
                            </div>
                            <div data-forumid="265" class="search_forum depth3  parent202 parent22 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="265">
                            project.log
                            </div>
                            </div>
                            <div class="forumlist">
                            <div data-forumid="219" class="search_forum depth2  parent22 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="219">
                            YOSPOS
                            </div>
                            <div data-forumid="192" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="192">
                            Inspect Your Gadgets
                            </div>
                            <div data-forumid="122" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="122">
                            Sports Argument Stadium
                            </div>
                            <div data-forumid="181" class="search_forum depth2  parent122 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="181">
                            The Football Funhouse
                            </div>
                            <div data-forumid="175" class="search_forum depth2  parent122 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="175">
                            The Ray Parlour
                            </div>
                            <div data-forumid="248" class="search_forum depth2  parent122 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="248">
                            The Armchair Quarterback
                            </div>
                            <div data-forumid="139" class="search_forum depth2  parent122 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="139">
                            Poker Is Totally Rigged
                            </div>
                            <div data-forumid="177" class="search_forum depth2  parent122 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="177">
                            Punch Sport Pagoda
                            </div>
                             <div data-forumid="179" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="179">
                            You Look Like Shit
                            </div>
                            <div data-forumid="183" class="search_forum depth2  parent179 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="183">
                            The Goon Doctor
                            </div>
                            <div data-forumid="244" class="search_forum depth2  parent179 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="244">
                            The Fitness Log Cabin
                            </div>
                            <div data-forumid="161" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="161">
                            Goons With Spoons
                            </div>
                            <div data-forumid="91" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="91">
                            Automotive Insanity
                            </div>
                            <div data-forumid="236" class="search_forum depth2  parent91 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="236">
                            Cycle Asylum
                            </div>
                            <div data-forumid="210" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="210">
                            Hobbies, Crafts, &amp; Houses
                            </div>
                            <div data-forumid="124" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="124">
                            Pet Island
                            </div>
                            <div data-forumid="132" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="132">
                            The Firing Range
                            </div>
                            <div data-forumid="277" class="search_forum depth2  parent132 parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="277">
                            The Pellet Palace
                            </div>
                            <div data-forumid="90" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="90">
                            The Crackhead Clubhouse
                            </div>
                            <div data-forumid="218" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="218">
                            Internet VFW
                            </div>
                            <div data-forumid="275" class="search_forum depth1  parent51 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="275">
                            The Minority Rapport
                            </div>
                            <div data-forumid="152" class="search_forum depth0  ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="152">
                            The Finer Arts
                            </div>
                            <div data-forumid="267" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="267">
                            Imp Zone
                            </div>
                            <div data-forumid="681" class="search_forum depth2  parent267 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="681">
                            The Enclosed Pool Area
                            </div>
                            <div data-forumid="274" class="search_forum depth2  parent267 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="274">
                            Blockbuster Video
                            </div>
                            <div data-forumid="668" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="668">
                            The Sci-Fi Wifi
                            </div>
                            <div data-forumid="151" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="151">
                            Cinema Discusso
                            </div>
                            <div data-forumid="133" class="search_forum depth2  parent151 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="133">
                            The Film Dump
                            </div>
                            <div data-forumid="150" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="150">
                            No Music Discussion
                            </div>
                            <div data-forumid="104" class="search_forum depth2  parent150 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="104">
                            Musician's Lounge
                            </div>
                            <div data-forumid="215" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="215">
                            PHIZ
                            </div>
                            </div>
                            <div class="forumlist">
                            <div data-forumid="31" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="31">
                            Creative Convention
                            </div>
                            <div data-forumid="247" class="search_forum depth2  parent31 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="247">
                            The Dorkroom
                            </div>
                            <div data-forumid="182" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="182">
                            The Book Barn
                            </div>
                            <div data-forumid="688" class="search_forum depth2  parent182 parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="688">
                            The Scholastic Book Fair
                            </div>
                            <div data-forumid="130" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="130">
                            TV IV
                            </div>
                            <div data-forumid="255" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="255">
                            Rapidly Going Deaf
                            </div>
                            <div data-forumid="144" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="144">
                            BSS: Bisexual Super Son
                            </div>
                            <div data-forumid="27" class="search_forum depth1  parent152 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="27">
                            Anime Directly to Readers Worldwide
                            </div>
                            <div data-forumid="153" class="search_forum depth0  ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="153">
                            The Community
                            </div>
                            <div data-forumid="61" class="search_forum depth1  parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="61">
                            SA-Mart
                            </div>
                            <div data-forumid="77" class="search_forum depth2  parent61 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="77">
                            Feedback &amp; Discussion
                            </div>
                            <div data-forumid="85" class="search_forum depth2  parent61 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="85">
                            Coupons &amp; Deals
                            </div>
                            <div data-forumid="241" class="search_forum depth1  parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="241">
                            LAN: Your City Sucks
                            </div>
                            <div data-forumid="43" class="search_forum depth2  parent241 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="43">
                            Goon Meets
                            </div>
                            <div data-forumid="686" class="search_forum depth1  parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="686">
                            Something Awful Discussion
                            </div>
                            <div data-forumid="687" class="search_forum depth2  parent686 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="687">
                            Resolved, Closed, or Duplicate SAD Threads
                            </div>
                            <div data-forumid="676" class="search_forum depth1  parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="676">
                            Technical Enquiries Contemplated Here
                            </div>
                            <div data-forumid="689" class="search_forum depth2  parent676 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="689">
                            Goon Rush
                            </div>
                            <div data-forumid="677" class="search_forum depth2  parent676 parent153 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="677">
                            Resolved Technical Forum Missives
                            </div>
                            <div data-forumid="49" class="search_forum depth0  ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="49">
                            Archives
                            </div>
                            <div data-forumid="21" class="search_forum depth1  parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="21">
                            Comedy Goldmine
                            </div>
                            <div data-forumid="680" class="search_forum depth2  parent21 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="680">
                            Imp Zone: Player's Choice
                            </div>
                            <div data-forumid="264" class="search_forum depth2  parent21 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="264">
                            The Goodmine
                            </div>
                            <div data-forumid="115" class="search_forum depth2  parent21 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="115">
                            FYAD: Criterion Collection
                            </div>
                            <div data-forumid="222" class="search_forum depth2  parent21 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="222">
                            LF Goldmine
                            </div>
                            <div data-forumid="176" class="search_forum depth2  parent21 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="176">
                            BYOB Goldmine: Gold Mango
                            </div>
                            <div data-forumid="25" class="search_forum depth1  parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="25">
                            Toxic Comedy Gas Waste Chamber Dump
                            </div>
                            <div data-forumid="1" class="search_forum depth1  parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="1">
                            GBS Graveyard
                            </div>
                            <div data-forumid="675" class="search_forum depth1  parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="675">
                            Questions, Comments, Suggestions
                            </div>
                            <div data-forumid="188" class="search_forum depth2  parent675 parent49 ">
                            <input type="checkbox" class="forumcheck" name="forums[]" value="188">
                            QCS Success Stories
                            </div>
                            </div>
                            </div>
                            </div>
                            </form>
                            """

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
    
    private let searchPageHTMLString: String
    private var searchResultsHtmlString: String = ""
    private var searchQueryID: String?
    

    
    init(
        forumSelectOptions: [ForumSelectOption] = [],
        searchPageHTMLString: String = defaultSearchPageHTMLString,
        searchHelpHints: [SearchHelpHint] = [],
        searchResults: [SearchResult] = []
    ) {
        self.forumSelectOptions = forumSelectOptions
        self.searchPageHTMLString = searchPageHTMLString
        self.searchHelpHints = searchHelpHints
        self.searchResults = searchResults
        
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
        await scrapeForumSelectOptions()
    }
    
    func scrapeForumSelectOptions() async {
        do {
            searchPageHtmlDoc = try htmlString2HtmlDocument(htmlString: searchPageHTMLString)
            
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
        } catch {
            print("Error scraping forum options: \(error)")
            searchState.message = "Failed to load forum options"
        }
    }
    
    func scrapeForumResultsPage(requestedPage: Int? = nil) async {
        do {
            searchResultsHtmlDoc = try htmlString2HtmlDocument(htmlString: searchResultsHtmlString)
            
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
                }
            }
        } catch {
            print("Error scraping search results: \(error)")
            searchState.message = "Failed to load search results"
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
        // Create URL components from the base URL
        guard let baseURL = ForumsClient.shared.baseURL else {
            searchState.message = "Invalid base URL"
            return
        }
        
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            searchState.message = "Invalid URL"
            return
        }
        
        // Add path and query items
        components.path = "/query.php"
        components.queryItems = [
            URLQueryItem(name: "q", value: searchState.query),
            URLQueryItem(name: "action", value: "query")
        ] + forumSelectOptions
            .filter(\.isSelected)
            .map { URLQueryItem(name: "forums[]", value: $0.value) }
        
        // Create the final URL and query string
        guard let url = components.url,
              let queryString = components.percentEncodedQuery?.data(using: String.Encoding.utf8) else {
            searchState.message = "Failed to create search URL"
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = queryString
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode.isSuccessful,
                  let htmlString = String(data: data, encoding: .utf8) else {
                searchState.message = "Search failed"
                return
            }
            
            searchResultsHtmlString = htmlString
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
        guard let baseURL = ForumsClient.shared.baseURL else {
            searchState.message = "Invalid base URL"
            return
        }
        
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            searchState.message = "Invalid URL"
            return
        }
        
        components.path = "/query.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "results"),
            URLQueryItem(name: "qid", value: qid),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = components.url else {
            searchState.message = "Could not create page URL."
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode.isSuccessful,
                  let htmlString = String(data: data, encoding: .utf8)
            else {
                searchState.message = "Failed to load page"
                return
            }
            
            searchResultsHtmlString = htmlString
            await scrapeForumResultsPage(requestedPage: page)
            
        } catch {
            searchState.message = "Failed to load page: \(error.localizedDescription)"
            print("Page load error: \(error)")
        }
    }
    
    private func htmlString2HtmlDocument(htmlString: String) throws -> HTMLDocument {
        return HTMLDocument(string: htmlString)
    }
    
    func clearHeavyObjects() {
        searchPageHtmlDoc = HTMLDocument(string: "")
        searchResultsHtmlDoc = nil
        searchResultsHtmlString = ""
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

