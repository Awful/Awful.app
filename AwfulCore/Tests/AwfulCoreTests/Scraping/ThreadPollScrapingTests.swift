//  ThreadPollScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader
import XCTest

final class ThreadPollScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    // MARK: - Ballot

    func testBallot() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll")
        let poll = result.poll

        XCTAssertEqual(poll.pollID, "39298")
        XCTAssertEqual(poll.question, "Posting a poll from the iOS app")
        XCTAssertFalse(poll.hasVoted)
        XCTAssertFalse(poll.hasResults)
        XCTAssert(poll.canVote)
        XCTAssertNil(poll.totalVotes)
        XCTAssertEqual(poll.editURL?.query, "action=polledit&pollid=39298")

        XCTAssertEqual(poll.options.count, 3)
        XCTAssertEqual(poll.options.map(\.id), [1, 2, 3])
        XCTAssertEqual(poll.options.map(\.text), ["Option two", "Option one", ":q:"])
        XCTAssertEqual(poll.options.map(\.formName), ["optionnumber[1]", "optionnumber[2]", "optionnumber[3]"])
        XCTAssertEqual(poll.options.map(\.formValue), ["yes", "yes", "yes"])
        XCTAssert(poll.options.allSatisfy { $0.voteCount == nil && $0.percentage == nil })

        let ballot = try XCTUnwrap(poll.ballot)
        XCTAssert(ballot.allowsMultipleChoice)
        XCTAssertEqual(ballot.actionPath, "poll.php")
        XCTAssertEqual(ballot.hiddenFields.first { $0.name == "action" }?.value, "pollvote")
        XCTAssertEqual(ballot.hiddenFields.first { $0.name == "pollid" }?.value, "39298")
    }

    /// An option that's nothing but a smilie has to read as its alt text, or the row comes out blank.
    func testSmilieOnlyOptionUsesAltText() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll")
        XCTAssertEqual(result.poll.options.last?.text, ":q:")
    }

    /// The flattened `text` is only good for accessibility and logging — the app draws `segments`,
    /// so a smilie has to survive as an image with a URL to draw.
    func testSmilieOptionKeepsTheImage() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll")
        let options = result.poll.options

        XCTAssertEqual(options[0].segments, [.text("Option two")])
        XCTAssertEqual(options[1].segments, [.text("Option one")])

        XCTAssertEqual(options[2].segments.count, 1)
        // Compare the absolute string rather than the URL: `URL(string:relativeTo:)` carries a base
        // around with it, and two URLs that print the same needn't be `==`.
        guard case .image(let url, let alt)? = options[2].segments.first else {
            return XCTFail("expected an image segment, got \(options[2].segments)")
        }
        XCTAssertEqual(alt, ":q:")
        XCTAssertEqual(url?.absoluteString, "https://fi.somethingawful.com/images/smilies/emot-q.gif")
    }

    /// Synthetic fixture: we've never captured a single-choice poll, so this pins down what we
    /// *expect* radio buttons to look like, including having no `optionnumber[N]` index to read.
    func testRadioBallotIsSingleChoice() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll-radio")
        let poll = result.poll

        let ballot = try XCTUnwrap(poll.ballot)
        XCTAssertFalse(ballot.allowsMultipleChoice)

        XCTAssertEqual(poll.options.count, 3)
        // No bracketed index in the name, so numbering falls back to position on the page.
        XCTAssertEqual(poll.options.map(\.id), [1, 2, 3])
        XCTAssertEqual(poll.options.map(\.formName), ["optionnumber", "optionnumber", "optionnumber"])
        XCTAssertEqual(poll.options.map(\.formValue), ["1", "2", "3"])
        XCTAssertEqual(poll.options.map(\.text), ["Option two", "Option one", ":q:"])
    }

    // MARK: - Results

    func testAlreadyVotedResults() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll-voted")
        let poll = result.poll

        XCTAssertEqual(poll.pollID, "38013")
        XCTAssertEqual(poll.question, "11111 ?")
        XCTAssert(poll.hasVoted)
        XCTAssert(poll.hasResults)
        XCTAssertFalse(poll.canVote)
        XCTAssertNil(poll.ballot)
        XCTAssertEqual(poll.totalVotes, 1)

        XCTAssertEqual(poll.options.count, 4)
        XCTAssertEqual(poll.options.map(\.text), ["Option 1", "Option 2", "Option 3", "Option 4"])
        XCTAssertEqual(poll.options.map(\.voteCount), [0, 1, 0, 0])
        XCTAssertEqual(poll.options.map(\.percentage), [0, 100, 0, 0])
        XCTAssert(poll.options.allSatisfy { $0.formName == nil && $0.formValue == nil })
    }

    /// The poll ID is only ever spelled out in the moderators-only "Edit Poll" link, so a regular
    /// account probably doesn't get one. That has to still scrape: the results are all inline.
    func testAlreadyVotedWithoutModeratorLink() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll-voted-nonmod")
        let poll = result.poll

        XCTAssertNil(poll.pollID)
        XCTAssertNil(poll.editURL)
        XCTAssertEqual(poll.question, "11111 ?")
        XCTAssert(poll.hasVoted)
        XCTAssertEqual(poll.totalVotes, 1)
        XCTAssertEqual(poll.options.map(\.voteCount), [0, 1, 0, 0])
    }

    /// The page behind the "View Results" link, which is how you see results without voting.
    ///
    /// Built by hand rather than via `scrapeHTMLFixture`, whose stand-in URL carries no `pollid` —
    /// and this page mentions the poll ID nowhere but the URL you asked with.
    func testShowResultsPage() throws {
        let url = URL(string: "https://forums.somethingawful.com/poll.php?action=showresults&pollid=39297")
        let result = try ThreadPollScrapeResult(htmlFixture(named: "poll-showresults"), url: url)
        let poll = result.poll

        XCTAssertEqual(poll.pollID, "39297")
        // The only mention of the thread is in the breadcrumbs.
        XCTAssertEqual(poll.threadID, "4115578")
        XCTAssertEqual(poll.question, "123456789012345678901234567890123456789012345678901234567890123456789")
        // This page never says whether we voted, and we shouldn't guess that we did.
        XCTAssertFalse(poll.hasVoted)
        XCTAssertNil(poll.ballot)

        // Every option is a bare smilie, so the alt text is all that keeps the rows from being blank.
        XCTAssertEqual(poll.options.map(\.text), [":q:", ":v:", ":toot:", ":keke:"])
        XCTAssertEqual(poll.options.map(\.voteCount), [0, 0, 0, 0])
        XCTAssertEqual(poll.options.map(\.percentage), [0, 0, 0, 0])

        // The crux: this page's total row is four columns and ends in "100%". Reading the last cell
        // reported "100 votes" for a poll nobody had voted in.
        XCTAssertEqual(poll.totalVotes, 0)
    }

    /// A real capture of a multiple-choice poll after voting, smilie option and all.
    ///
    /// One person voted for all three options, so the forums report three option votes but a total
    /// of one — the total counts *voters*. Deriving it by summing would say three, which is why we
    /// only ever read it out of the markup.
    func testMultipleChoiceResultsCountVotersNotSelections() throws {
        let result = try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread-poll-voted-multi")
        let poll = result.poll

        XCTAssertEqual(poll.pollID, "39298")
        XCTAssertEqual(poll.question, "Posting a poll from the iOS app")
        XCTAssert(poll.hasVoted)
        XCTAssertNil(poll.ballot)

        XCTAssertEqual(poll.options.map(\.voteCount), [1, 1, 1])
        XCTAssertEqual(poll.totalVotes, 1)

        XCTAssertEqual(poll.options.map(\.text), ["Option two", "Option one", ":q:"])
        // The smilie survives as an image in the results table too, not just on the ballot.
        guard case .image(_, let alt)? = poll.options.last?.segments.first else {
            return XCTFail("expected the third option to be a smilie image")
        }
        XCTAssertEqual(alt, ":q:")

        for percentage in poll.options.map(\.percentage) {
            XCTAssertEqual(try XCTUnwrap(percentage), 33.33, accuracy: 0.001)
        }
    }

    /// Isolates the rule behind the "100 votes so far" bug, which `testShowResultsPage` covers on
    /// the real page: the total row's column count follows the table around it, so its last cell
    /// can be a *percentage* rather than the count.
    func testTotalRowIsNotConfusedByATrailingPercentage() throws {
        let html = HTMLDocument(string: """
            <table class="standard">
            <tr><th colspan="4"><b>Nobody voted</b></th></tr>
            <tr>
                <td align="right">Option one</td>
                <td class="graphbar"><img src="bar2.gif" width="0" height="10" alt=""></td>
                <td width="67">0</td>
                <td align="center" width="67">0%</td>
            </tr>
            <tr>
                <td align="right" colspan="2"><b>Total:</b></td>
                <td width="67"><b>0</b></td>
                <td align="center" width="67"><b>100%</b></td>
            </tr>
            </table>
            """)
        let result = try ThreadPollScrapeResult(html, url: URL(string: "https://example.com/poll.php?pollid=1"))

        XCTAssertEqual(result.poll.totalVotes, 0)
        XCTAssertEqual(result.poll.options.map(\.voteCount), [0])
    }

    // MARK: - Not a poll

    func testOrdinaryThreadHasNoPoll() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(ThreadPollScrapeResult.self, named: "showthread"))
    }

    /// The most important test here: a selector that accidentally matched ordinary markup would put
    /// a phantom poll toast on every thread in the app.
    func testNoFalsePositivesOnOrdinaryThreads() throws {
        for name in ["showthread", "showthread2", "showthread-last",
                     "showthread-oneuser", "showthread-fyad", "showthread-fyad2"] {
            let result = try scrapeHTMLFixture(PostsPageScrapeResult.self, named: name)
            XCTAssertNil(result.poll, "\(name) should have no poll")
        }
    }

    // MARK: - Via the posts page

    func testPostsPageCarriesTheBallot() throws {
        let result = try scrapeHTMLFixture(PostsPageScrapeResult.self, named: "showthread-poll")
        XCTAssertEqual(result.threadID?.rawValue, "4115581")
        XCTAssertEqual(result.posts.count, 1)

        let poll = try XCTUnwrap(result.poll)
        XCTAssertEqual(poll.pollID, "39298")
        XCTAssertEqual(poll.options.count, 3)
        XCTAssert(poll.canVote)
        // Only the page knows this, and we need it to go back for the authoritative totals.
        XCTAssertEqual(poll.threadID, "4115581")
    }

    func testPostsPageCarriesTheResults() throws {
        let result = try scrapeHTMLFixture(PostsPageScrapeResult.self, named: "showthread-poll-voted")
        XCTAssertEqual(result.threadID?.rawValue, "4019450")
        XCTAssertEqual(result.posts.count, 1)

        let poll = try XCTUnwrap(result.poll)
        XCTAssertEqual(poll.question, "11111 ?")
        XCTAssert(poll.hasVoted)
        XCTAssertEqual(poll.totalVotes, 1)
    }
}
