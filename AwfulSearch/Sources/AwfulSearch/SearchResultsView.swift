//  SearchResultsView.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulExtensions
import AwfulTheming
import SwiftUI
import UIKit

/// A page of search results, with pagination along the bottom.
///
/// Chrome lives on ``SearchResultsViewController``; see ``SearchFormView`` for why.
struct SearchResultsView: View {
    @ObservedObject var model: SearchPageViewModel
    @SwiftUI.Environment(\.theme) var theme
    /// Opening a result is the view controller's job, since it depends on where this screen sits in
    /// the navigation stack.
    let onSelect: (SearchResult) -> Void

    private let topID = "top"

    var body: some View {
        VStack(spacing: 0) {
            if model.isRestoring {
                restoringView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
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
                            .background(theme[color: "sheetBackgroundColor"]!)
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
                    .background(theme[color: "backgroundColor"]!)
                    .onChange(of: model.currentPage) { _ in
                        withAnimation {
                            proxy.scrollTo(topID, anchor: .top)
                        }
                    }
                }
            }

            paginationBar
        }
        .background(theme[color: "backgroundColor"]!.ignoresSafeArea(.all))
        .applyFontDesign(if: theme.roundedFonts)
    }

    /// Shown while a restored search's results are being fetched again.
    private var restoringView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(theme[color: "listSecondaryTextColor"])
            Text("Loading your last search…", bundle: .module)
                .font(.subheadline)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The app's `NavigationController` doesn't manage a bottom toolbar — `PostsPageView` and
    /// `RapSheetViewController` each carry their own — and a nav toolbar would compete with the tab
    /// bar for the same space, so the pagination controls live in the content instead.
    private var paginationBar: some View {
        paginationControls
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                theme[color: "tabBarBackgroundColor"]
                    .overlay(alignment: .top) {
                        theme[color: "bottomBarTopBorderColor"]?
                            .frame(height: 1 / UIScreen.main.scale)
                    }
            )
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
            
            Text("\(model.currentPage) of \(model.totalPages)", bundle: .module)
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

// MARK: - View controller

/// Hosts ``SearchResultsView`` as a real screen in the app's navigation stack, so the posts page a
/// result opens can be backed out of straight into these results.
public final class SearchResultsViewController: HostingController<AnyView> {

    private let model: SearchPageViewModel

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
