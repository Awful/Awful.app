//  SearchPageViewModel.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulCore
import HTMLReader
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SearchPageViewModel")

// MARK: - View Models
@MainActor
final class SearchPageViewModel: ObservableObject {
    @Published var searchState = SearchState()
    @Published var forumSelectOptions: [ForumSelectOption] = []
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var searchHelpHints: [SearchHelpHint] = []
    /// True while a restored search is being fetched, so the results screen can show a spinner
    /// instead of an empty list.
    @Published private(set) var isRestoring = false
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var totalPages: Int = 1
    
    private var searchQueryID: String?
    let threadID: String?

    /// What the app does on the search screens' behalf; see ``SearchHandlers``.
    let handlers: SearchHandlers

    /// Called when a search has a page of results worth showing, so the host can push the results
    /// screen. Fires on every successful search, so the host must ignore it when results are
    /// already on top (a restore pushes them up front).
    var onResultsReady: (() -> Void)?

    /// Called when a restore turns out to have outlived its query ID: the host should return to the
    /// search form and pass the message on to the reader.
    var onRestoreFailed: ((String) -> Void)?

    /// Forum selections carried in from a restore, since the form they came from hasn't loaded yet.
    private var restoredForumIDs: [String] = []

    init(
        threadID: String? = nil,
        restoring: LastSearchStore.Record? = nil,
        handlers: SearchHandlers = .init(openPost: { _, _ in })
    ) {
        self.handlers = handlers
        // A restored search keeps the scope it was run in, so the forum picker and the `threadid:`
        // prefix stay consistent if the user backs out and searches again.
        self.threadID = restoring?.threadID ?? threadID

        // Set before the task below, which doesn't run until a later turn: otherwise the results
        // screen gets a frame on screen showing "no results" before the restore starts.
        if restoring != nil {
            isRestoring = true
        }

        Task { [weak self] in
            if let restoring {
                await self?.restoreLastResults(restoring)
            } else {
                await self?.loadInitialData()
            }
        }
    }
    
    var allForumsBinding: Binding<Bool> {
        Binding<Bool>(
            get: { [weak self] in
                guard let self else { return false }
                return !self.forumSelectOptions.isEmpty && self.forumSelectOptions.allSatisfy(\.isSelected)
            },
            set: { [weak self] newValue in
                guard let self, newValue != self.forumSelectOptions.allSatisfy(\.isSelected) else { return }
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
        do {
            let document = try await ForumsClient.shared.fetchSearchPage()
            htmlString = document.innerHTML
        } catch {
            logger.error("could not fetch the search page: \(error)")
            searchState.message = "Failed to load search page: \(error.localizedDescription)"
            return
        }

        await scrapeForumSelectOptions(from: HTMLDocument(string: htmlString))
    }

    /// - Note: the parsed document is deliberately a parameter rather than a stored property. It's by
    ///   far the heaviest thing here and nothing renders it, so it should not outlive the scrape.
    func scrapeForumSelectOptions(from document: HTMLDocument) async {
        if let forumListHtmlDoc = document.firstNode(matchingParsedSelector: .cached("form[action='query.php']")) {
            // Extract search message
            searchState.message = forumListHtmlDoc.firstNode(matchingParsedSelector: .cached(".search_message"))?.textContent ?? ""
            
            // Extract help hints
            if let searchHelpText = forumListHtmlDoc.firstNode(matchingParsedSelector: .cached(".search_help")) {
                searchHelpHints = searchHelpText.nodes(matchingParsedSelector: .cached(".term")).map { node in
                    SearchHelpHint(text: node.textContent)
                }
            }
            
            // Extract forum options
            forumSelectOptions = forumListHtmlDoc.nodes(matchingParsedSelector: .cached(".search_forum"))
                .compactMap { div -> ForumSelectOption? in
                    guard let input = div.firstNode(matchingParsedSelector: .cached(".forumcheck")),
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
    
    /// - Note: the parsed document is deliberately a parameter rather than a stored property. It's by
    ///   far the heaviest thing here and nothing renders it, so it should not outlive the scrape.
    func scrapeForumResultsPage(_ resultHtmlDoc: HTMLDocument, requestedPage: Int? = nil) async {
        searchState.resultInfo = resultHtmlDoc.firstNode(matchingParsedSelector: .cached("#search_info"))?.textContent ?? ""
        
        searchResults = resultHtmlDoc.nodes(matchingParsedSelector: .cached(".search_result")).map { searchResult in
            let blurbNode: HTMLNode? = searchResult.firstNode(matchingParsedSelector: .cached(".blurb"))
            let blurb: String
            if let element = blurbNode as? HTMLElement {
                blurb = element.innerHTML
            } else {
                blurb = blurbNode?.textContent ?? ""
            }
            return SearchResult(
                threadTitle: searchResult.firstNode(matchingParsedSelector: .cached(".threadtitle"))?.textContent ?? "",
                resultNumber: searchResult.firstNode(matchingParsedSelector: .cached(".result_number"))?.textContent ?? "",
                blurb: blurb,
                postID: searchResult.firstNode(matchingParsedSelector: .cached(".threadtitle"))?["href"]
                    .flatMap { URLComponents(string: $0) }?
                    .queryItems?
                    .first { $0.name == "postid" }?
                    .value ?? "",
                postedDateTime: searchResult.firstNode(matchingParsedSelector: .cached(".hit_info"))?.textContent ?? ""
            )
        }
        
        if let pagesDiv = resultHtmlDoc.firstNode(matchingParsedSelector: .cached(".pages")) {
            if let currentPageNode = pagesDiv.firstNode(matchingParsedSelector: .cached("b")) {
                self.currentPage = Int(currentPageNode.textContent.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            } else if let requestedPage = requestedPage {
                self.currentPage = requestedPage
            }
            
            let pageLinks = pagesDiv.nodes(matchingParsedSelector: .cached("a"))
            var maxPage = currentPage

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

        // Last thing, so the remembered page is whatever we actually ended up showing.
        persistLastSearch()
    }

    /// Remembers this page of results so it can be fetched again after the search screen goes away.
    ///
    /// Called from every successful scrape rather than on the way out, so the record is already
    /// safely stored by the time the model goes away with the sheet.
    private func persistLastSearch() {
        guard let searchQueryID else { return }
        // Nothing worth coming back to if the page held neither results nor the "no results" blurb.
        guard !searchResults.isEmpty || !searchState.resultInfo.isEmpty else { return }

        // Straight after a restore the form hasn't been fetched, so fall back to the selections the
        // record came with rather than saving an empty list over them.
        let forumIDs = forumSelectOptions.isEmpty
            ? restoredForumIDs
            : forumSelectOptions.filter(\.isSelected).map(\.value)

        LastSearchStore.save(.init(
            queryID: searchQueryID,
            page: currentPage,
            query: searchState.query,
            threadID: threadID,
            forumIDs: forumIDs
        ))
    }

    /// Digs the forums' query ID out of a results page, so it can be asked for again later.
    ///
    /// The response URL is the reliable source — a search POST redirects to
    /// `query.php?action=results&qid=N`. The pagination links are the fallback, and only carry a
    /// query ID when there's more than one page of results.
    private func captureQueryID(from document: HTMLDocument, responseURL: URL?) -> String? {
        if let responseURL,
           let components = URLComponents(url: responseURL, resolvingAgainstBaseURL: true),
           let qid = components.queryItems?.first(where: { $0.name == "qid" })?.value,
           !qid.isEmpty {
            logger.debug("query ID \(qid) from response URL")
            return qid
        }

        for link in document.nodes(matchingParsedSelector: .cached("a")) {
            guard let href = link["href"],
                  let url = URL(string: href, relativeTo: ForumsClient.shared.baseURL),
                  url.path.contains("query.php"),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let qid = components.queryItems?.first(where: { $0.name == "qid" })?.value,
                  !qid.isEmpty
            else { continue }
            logger.debug("query ID \(qid) from a link on the results page")
            return qid
        }

        logger.warning("no query ID on this results page; it won't be restorable")
        return nil
    }

    /// Whether a document looks like a page of search results rather than an expiry or error page.
    ///
    /// A search that found nothing still counts: it has no `.search_result` nodes but does explain
    /// itself in `#search_info`, and `SearchResultsView` knows how to show that.
    private func looksLikeResults(_ document: HTMLDocument) -> Bool {
        if document.firstNode(matchingParsedSelector: .cached(".search_result")) != nil { return true }
        let info = document.firstNode(matchingParsedSelector: .cached("#search_info"))?.textContent ?? ""
        return !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        searchState.resultsMessage = ""

        let forumIDs = forumSelectOptions
            .filter(\.isSelected)
            .map(\.value)

        let outgoingQuery: String = {
            guard let threadID, !threadID.isEmpty else { return searchState.query }
            return "threadid:\(threadID) \(searchState.query)"
        }()

        do {
            let (document, responseURL) = try await ForumsClient.shared.searchForums(
                query: outgoingQuery,
                forumIDs: forumIDs
            )

            // Reset pagination state before publishing the new document, so the results screen never
            // shows the previous search's rows against the new search's page count.
            self.currentPage = 1
            self.totalPages = 1
            self.searchResults.removeAll()
            self.searchState.resultInfo = ""
            self.searchQueryID = captureQueryID(from: document, responseURL: responseURL)

            // Show the results screen before scraping, so it appears as soon as the request lands
            // rather than after the parse.
            onResultsReady?()

            await scrapeForumResultsPage(document)

        } catch {
            searchState.message = "Search failed: \(error.localizedDescription)"
            logger.error("search failed: \(error)")
        }
    }

    func goToPage(page: Int) async {
        guard let qid = searchQueryID else {
            searchState.resultsMessage = "Cannot navigate to page, no query ID."
            return
        }

        searchState.resultsMessage = ""

        do {
            let document = try await ForumsClient.shared.searchForumsPage(
                queryID: qid,
                page: page
            )

            // A query ID that's aged out mid-browse comes back as something other than results.
            guard looksLikeResults(document) else {
                await fallBackToSearchForm(document: document)
                return
            }

            await scrapeForumResultsPage(document, requestedPage: page)

        } catch {
            searchState.resultsMessage = "Failed to load page: \(error.localizedDescription)"
            logger.error("could not load results page: \(error)")
        }
    }

    /// Fetches the results the user was last looking at, using the query ID we kept.
    func restoreLastResults(_ record: LastSearchStore.Record) async {
        // Show what was typed, not the `threadid:N ` the forums were actually sent.
        searchState.query = record.query
        restoredForumIDs = record.forumIDs

        let document: HTMLDocument
        do {
            document = try await ForumsClient.shared.searchForumsPage(
                queryID: record.queryID,
                page: record.page
            )
        } catch {
            logger.error("search restore failed: \(error)")
            await fallBackToSearchForm(document: nil, preservingForumIDs: record.forumIDs)
            return
        }

        guard looksLikeResults(document) else {
            await fallBackToSearchForm(document: document, preservingForumIDs: record.forumIDs)
            return
        }

        searchQueryID = record.queryID
        currentPage = record.page
        totalPages = max(totalPages, record.page)
        await scrapeForumResultsPage(document, requestedPage: record.page)

        isRestoring = false

        // The search form is only needed if the user backs out of the results, so it can trail in.
        Task { [weak self] in
            await self?.fetchAndParseSearchPage()
            self?.applySelectedForumIDs(record.forumIDs)
        }
    }

    /// Gives up on a restore and shows the search form instead, letting the host explain why.
    ///
    /// Passing the failed response lets us reuse it when the forums answered with the search form
    /// itself, which saves a second round trip in the common expiry case.
    private func fallBackToSearchForm(document: HTMLDocument?, preservingForumIDs: [String]? = nil) async {
        // Clear the dead record even if nobody's watching any more.
        LastSearchStore.clear()

        searchQueryID = nil
        searchResults.removeAll()
        searchState.resultInfo = ""
        currentPage = 1
        totalPages = 1

        // Whatever the user had ticked, or — restoring, where the form was never shown — whatever
        // they had ticked when the search was first run.
        let selectedForumIDs = preservingForumIDs ?? forumSelectOptions.filter(\.isSelected).map(\.value)

        if let document, document.firstNode(matchingParsedSelector: .cached("form[action='query.php']")) != nil {
            await scrapeForumSelectOptions(from: document)
        } else {
            await fetchAndParseSearchPage()
        }
        applySelectedForumIDs(selectedForumIDs)

        isRestoring = false
        onRestoreFailed?("Those search results have expired. Try searching again.")
    }

    private func applySelectedForumIDs(_ forumIDs: [String]) {
        guard !forumIDs.isEmpty else { return }
        let selected = Set(forumIDs)
        for i in forumSelectOptions.indices {
            forumSelectOptions[i].isSelected = selected.contains(forumSelectOptions[i].value)
        }
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
    let postID: String
    let postedDateTime: String
}

struct SearchHelpHint: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct SearchState {
    var query: String = ""
    /// Shown on the search form. Doubles as the forums' own "search_message" notice.
    var message: String = ""
    /// Shown on the results screen. Separate from `message`, which the form keeps overwriting.
    var resultsMessage: String = ""
    var resultInfo: String = ""
}

// MARK: - Last search restore

/**
 The most recent search results, remembered well enough to fetch them again.

 The results screen itself is thrown away as soon as a result is tapped, and search results don't
 stay valid for long anyway. What's kept instead is the forums' own query ID, which can be handed
 back to `query.php?action=results&qid=N&page=M` to rebuild the same results on demand. The forums
 expire a query ID after a while; when that happens the restore fails and the user is dropped on a
 fresh search form.

 This deliberately lives outside `SearchPageViewModel`: the model goes away with the sheet, which is
 exactly the moment we need the query ID to survive.

 One slot, shared by forum-wide and thread-scoped searches — whichever ran last is what comes back.
 In-memory only, since a query ID belongs to a login session and won't outlive one. Static state is
 shared across scenes, so on iPad both windows see the same last search; that's fine for what this
 is.
 */
@MainActor
public enum LastSearchStore {
    public struct Record {
        /// The forums' query ID, good for `query.php?action=results&qid=…` until it expires.
        var queryID: String
        var page: Int
        /// What the user typed, *without* the `threadid:N ` prefix a thread-scoped search adds.
        var query: String
        /// The thread a thread-scoped search was run in, or nil for a forum-wide search.
        var threadID: String?
        /// Which forums were ticked, so backing out to the form doesn't lose the selection.
        var forumIDs: [String]
    }

    private static var stored: Record?

    public static var record: Record? { stored }
    public static var hasStoredResults: Bool { stored != nil }

    static func save(_ record: Record) {
        stored = record
    }

    public static func clear() {
        stored = nil
    }
}
