//  ThreadPollScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/**
 A poll scraped off a thread page or off `poll.php`.

 Three markup shapes turn up, and this handles all of them:

 1. A `<form>` with a hidden `action=pollvote`, one checkbox (or radio button) per option. This is
    what a thread page shows when you haven't voted.
 2. A table of results with a `td.graphbar` per row, headed "You have already voted on this poll."
    This is what a thread page shows once you have.
 3. `poll.php?action=showresults`, which is shape 2 without the "already voted" line.

 We go looking for these by shape rather than by position on the page. A poll sits between the
 breadcrumbs and the thread bar, but neither of those is reliably around (they're missing from
 `poll.php` entirely), and shape 2 has no form to anchor on.
 */
public struct ThreadPollScrapeResult: ScrapeResult {

    public let poll: ThreadPoll

    /// - Throws: `ScrapingError.missingExpectedElement` if there's no poll here at all.
    public init(_ html: HTMLNode, url: URL?) throws {
        var poll = ThreadPoll()

        let ballotForm = Self.findBallotForm(in: html, url: url)
        if let (element, form) = ballotForm {
            Self.applyBallot(element: element, form: form, baseURL: url, to: &poll)
        }

        // Look for results even when we found a ballot: it costs one selector, and covers a
        // `poll.php` response that happens to carry both.
        if let resultsTable = Self.findResultsTable(in: html) {
            Self.applyResults(table: resultsTable, baseURL: url, to: &poll)
        }

        guard ballotForm != nil || poll.hasResults else {
            throw ScrapingError.missingExpectedElement("form input[name = 'pollid'], td.graphbar")
        }

        // A thread has at most one poll, so it's safe to go looking page-wide for the moderators'
        // "Edit Poll" link rather than fussing over which container it landed in.
        poll.editURL = Self.editURL(within: html, relativeTo: url)

        // `poll.php` names the thread only in its breadcrumbs. A thread page has `body[data-thread]`
        // too, and `PostsPageScrapeResult` fills that in afterwards; this covers the other case.
        poll.threadID = Self.queryItem("threadid", inLinkMatching: "div.breadcrumbs a[href *= 'threadid']", within: html, relativeTo: url)
        if poll.pollID == nil {
            poll.pollID = Self.pollID(inLinkMatching: "a[href *= 'polledit']", within: html, relativeTo: url)
                ?? Self.pollID(inLinkMatching: "a[href *= 'showresults']", within: html, relativeTo: url)
                // Shape 3 carries no such link, but we asked for it by poll ID in the first place,
                // so the URL knows.
                ?? url.flatMap { Self.pollID(inURL: $0) }
        }

        self.poll = poll
    }

    // MARK: - Ballot (shape 1)

    /// The first `<form>` on the page that submits a vote. Matching on the hidden `action` value is
    /// what keeps us from mistaking the *new poll* form (`action=postpoll`) for this one, which
    /// matters because `poll.php` serves either depending on how you got there.
    private static func findBallotForm(in html: HTMLNode, url: URL?) -> (HTMLElement, Form)? {
        for element in html.nodes(matchingParsedSelector: .cached("form")) {
            guard let form = try? Form(element, url: url) else { continue }
            let castsAVote = form.controls.contains { control in
                if case .hidden(name: "action", value: "pollvote", isDisabled: false) = control {
                    return true
                }
                return false
            }
            if castsAVote {
                return (element, form)
            }
        }
        return nil
    }

    private static func applyBallot(element: HTMLElement, form: Form, baseURL: URL?, to poll: inout ThreadPoll) {
        let hiddenFields = form.controls.compactMap { (control) -> ThreadPoll.HiddenField? in
            guard case .hidden(let name, let value, isDisabled: false) = control else { return nil }
            return ThreadPoll.HiddenField(name: name, value: value)
        }

        let optionInputs = element.nodes(matchingParsedSelector: .cached("input[type = 'checkbox'], input[type = 'radio']"))

        // Checkboxes mean pick as many as you like; radio buttons mean pick one.
        let allowsMultipleChoice = optionInputs.contains { $0["type"]?.lowercased() == "checkbox" }

        poll.options = optionInputs.enumerated().compactMap { (index, input) -> ThreadPoll.Option? in
            let name = input["name"] ?? ""
            guard !name.isEmpty else { return nil }
            // Fall back to position if the forums ever stop numbering these.
            let id = optionIndex(forControlNamed: name) ?? (index + 1)
            let labelCell = input.ancestorElement(tagName: "td")?.nextSiblingElement
            let labelSegments = labelCell.map { segments(of: $0, baseURL: baseURL) } ?? []
            return ThreadPoll.Option(
                id: id,
                text: plainText(of: labelSegments),
                segments: labelSegments,
                rawHTML: labelCell?.innerHTML ?? "",
                formName: name,
                // Never assume "yes"; read what the markup actually wants.
                formValue: input["value"] ?? "on"
            )
        }

        poll.ballot = ThreadPoll.Ballot(
            allowsMultipleChoice: allowsMultipleChoice,
            actionPath: (element["action"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            hiddenFields: hiddenFields
        )

        poll.question = questionFromHeader(in: element) ?? poll.question
        poll.pollID = hiddenFields.first { $0.name == "pollid" }?.value
    }

    // MARK: - Results (shapes 2 and 3)

    /// `td.graphbar` is the poll-results bar and appears nowhere else on the forums, which makes it
    /// a much safer anchor than `table.standard` (used all over) or the surrounding `<center>`.
    private static func findResultsTable(in html: HTMLNode) -> HTMLElement? {
        html.firstNode(matchingParsedSelector: .cached("td.graphbar"))?
            .ancestorElement(tagName: "table")
    }

    private static func applyResults(table: HTMLElement, baseURL: URL?, to poll: inout ThreadPoll) {
        if let header = table.firstNode(matchingParsedSelector: .cached("th")) {
            let headerText = header.textContent
            poll.hasVoted = headerText.range(of: "already voted", options: .caseInsensitive) != nil
            // The question is in a <b>; the "already voted" sentence is a sibling outside it.
            if let bold = header.firstNode(matchingParsedSelector: .cached("b")) {
                poll.question = collapsingWhitespace(bold.textContent)
            } else if poll.question.isEmpty {
                poll.question = collapsingWhitespace(
                    headerText.replacingOccurrences(
                        of: "You have already voted on this poll.",
                        with: "",
                        options: .caseInsensitive
                    )
                )
            }
        }

        let rows = table.nodes(matchingParsedSelector: .cached("tr"))

        // Filtering on "has a graphbar" picks out exactly the option rows, leaving the header and
        // the total row behind without any index arithmetic.
        let (optionRows, otherRows) = rows.reduce(into: ([HTMLElement](), [HTMLElement]())) { acc, row in
            if row.firstNode(matchingParsedSelector: .cached("td.graphbar")) != nil {
                acc.0.append(row)
            } else {
                acc.1.append(row)
            }
        }

        // The total lives in its own row, and is not the sum of the option counts: a multiple-choice
        // poll lets one voter pick several options. If the forums don't tell us, we don't know.
        // Searching only the non-option rows means an option labelled "Total:" can't hijack this.
        poll.totalVotes = otherRows
            .first { $0.textContent.range(of: "Total:", options: .caseInsensitive) != nil }
            .flatMap(totalVotes(inRow:))

        let scrapedOptions = optionRows.enumerated().compactMap { (index, row) -> ThreadPoll.Option? in
            let cells = row.nodes(matchingParsedSelector: .cached("td"))
            guard let labelCell = cells.first else { return nil }

            let countCell: HTMLElement?
            let percentCell: HTMLElement?
            if cells.count >= 4,
               let graphbar = row.firstNode(matchingParsedSelector: .cached("td.graphbar")) {
                countCell = graphbar.nextSiblingElement
                percentCell = countCell?.nextSiblingElement
            } else {
                // We've never seen a results table with a different number of columns, but the
                // `showresults` page is unsampled, so take the last two cells and hope.
                countCell = cells.count >= 2 ? cells[cells.count - 2] : nil
                percentCell = cells.count >= 2 ? cells[cells.count - 1] : nil
            }

            let labelSegments = segments(of: labelCell, baseURL: baseURL)
            return ThreadPoll.Option(
                id: index + 1,
                text: plainText(of: labelSegments),
                segments: labelSegments,
                rawHTML: labelCell.innerHTML,
                voteCount: countCell.flatMap { integer(in: $0.textContent) },
                percentage: percentCell.flatMap { percentage(in: $0.textContent) },
                formName: nil,
                formValue: nil
            )
        }

        // A ballot already gave us the options, complete with their form controls; merge the counts
        // in by position rather than throwing that away.
        if poll.options.isEmpty {
            poll.options = scrapedOptions
        } else if poll.options.count == scrapedOptions.count {
            for index in poll.options.indices {
                poll.options[index].voteCount = scrapedOptions[index].voteCount
                poll.options[index].percentage = scrapedOptions[index].percentage
            }
        }

        // Percentages are usually spelled out, but derive them if this shape doesn't.
        if let total = poll.totalVotes, total > 0 {
            for index in poll.options.indices where poll.options[index].percentage == nil {
                if let count = poll.options[index].voteCount {
                    poll.options[index].percentage = Double(count) / Double(total) * 100
                }
            }
        }

    }

    // MARK: - Odds and ends

    private static func questionFromHeader(in node: HTMLNode) -> String? {
        node.firstNode(matchingParsedSelector: .cached("th"))
            .map { $0.firstNode(matchingParsedSelector: .cached("b")) ?? $0 }
            .map { collapsingWhitespace($0.textContent) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func editURL(within node: HTMLNode, relativeTo url: URL?) -> URL? {
        node.firstNode(matchingParsedSelector: .cached("a[href *= 'polledit']"))?["href"]
            .flatMap { URL(string: $0, relativeTo: url) }
    }

    private static func pollID(inLinkMatching selector: String, within node: HTMLNode, relativeTo url: URL?) -> String? {
        queryItem("pollid", inLinkMatching: selector, within: node, relativeTo: url)
    }

    private static func queryItem(
        _ name: String,
        inLinkMatching selector: String,
        within node: HTMLNode,
        relativeTo url: URL?
    ) -> String? {
        for link in node.nodes(matchingParsedSelector: .cached(selector)) {
            guard let href = link["href"],
                  // The `relativeTo:` is only there so a relative href parses at all; any absolute
                  // base works, since all we want back out is a query item.
                  let linkURL = URL(string: href, relativeTo: url ?? URL(string: "https://forums.somethingawful.com/")),
                  let value = queryItem(name, inURL: linkURL)
            else { continue }
            return value
        }
        return nil
    }

    private static func pollID(inURL url: URL) -> String? {
        queryItem("pollid", inURL: url)
    }

    private static func queryItem(_ name: String, inURL url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first { $0.name.lowercased() == name.lowercased() }?
            .value
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}

// MARK: - Free functions

/**
 Breaks a label cell into runs of text and images.

 Poll options are usually plain words, but they can be — and on the forums often are — a bare smilie.
 Keeping the image separate lets the app draw the smilie instead of printing `":q:"` at the reader.
 */
private func segments(of element: HTMLElement, baseURL: URL?) -> [ThreadPoll.Option.Segment] {
    var segments: [ThreadPoll.Option.Segment] = []

    func appendText(_ string: String) {
        guard !string.isEmpty else { return }
        // Merge adjacent text so "a <b>b</b> c" doesn't become three runs.
        if case .text(let existing)? = segments.last {
            segments[segments.count - 1] = .text(existing + string)
        } else {
            segments.append(.text(string))
        }
    }

    func walk(_ node: HTMLNode) {
        guard let element = node as? HTMLElement else {
            return appendText(node.textContent)
        }
        if element.tagName.lowercased() == "img" {
            let alt = element["alt"] ?? element["title"] ?? ""
            let url = element["src"].flatMap { URL(string: $0, relativeTo: baseURL) }
            segments.append(.image(url: url, alt: alt))
            return
        }
        for child in element.children.compactMap({ $0 as? HTMLNode }) {
            walk(child)
        }
    }

    walk(element)

    // Tidy the text runs without disturbing the images between them.
    return segments.compactMap { (segment) -> ThreadPoll.Option.Segment? in
        guard case .text(let string) = segment else { return segment }
        let collapsed = collapsingWhitespace(string)
        return collapsed.isEmpty ? nil : .text(collapsed)
    }
}

/// The flattened form of `segments`, with images standing in as their alt text so that an option
/// consisting of nothing but a smilie reads as `":q:"` rather than as nothing at all.
private func plainText(of segments: [ThreadPoll.Option.Segment]) -> String {
    collapsingWhitespace(segments.map { segment in
        switch segment {
        case .text(let string): string
        case .image(_, let alt): alt
        }
    }.joined(separator: " "))
}

private func collapsingWhitespace(_ string: String) -> String {
    string
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

/**
 The vote count out of a "Total:" row.

 Not simply the last cell: the row's column count follows whatever the surrounding table uses, so on
 a four-column layout the last cell is a *percentage*, and grabbing it reports "100 votes" for a poll
 nobody has voted in. Take the cell that says "votes" outright, and failing that the last cell that
 holds a number and isn't a percentage.
 */
private func totalVotes(inRow row: HTMLElement) -> Int? {
    let cells = row.nodes(matchingParsedSelector: .cached("td"))

    if let stated = cells.first(where: { $0.textContent.range(of: "vote", options: .caseInsensitive) != nil }),
       let count = integer(in: stated.textContent) {
        return count
    }

    return cells
        .reversed()
        .first { !$0.textContent.contains("%") && integer(in: $0.textContent) != nil }
        .flatMap { integer(in: $0.textContent) }
}

/// Pulls the digits out of e.g. `"1 votes"` or `"1,024"`. Deliberately not `Scanner.scanInt()`,
/// which stops dead at a thousands separator.
private func integer(in string: String) -> Int? {
    let digits = string.filter { $0.isNumber }
    return digits.isEmpty ? nil : Int(digits)
}

/// Pulls a percentage out of e.g. `"100.00%"` or `"0%"`.
private func percentage(in string: String) -> Double? {
    let allowed = string.filter { $0.isNumber || $0 == "." }
    return allowed.isEmpty ? nil : Double(allowed)
}

/// The 1-based index in `optionnumber[3]`, or nil if `name` isn't a poll option at all.
private func optionIndex(forControlNamed name: String) -> Int? {
    guard name.hasPrefix("optionnumber["), name.hasSuffix("]") else { return nil }
    return Int(name.dropFirst("optionnumber[".count).dropLast())
}
