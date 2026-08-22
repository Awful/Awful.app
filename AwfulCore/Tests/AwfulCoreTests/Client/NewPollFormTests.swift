//  NewPollFormTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class NewPollFormTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        testInit()
    }

    private func newPollForm() throws -> NewPollForm {
        try NewPollForm(scrapeForm(matchingSelector: "form[action = 'poll.php']", inFixtureNamed: "poll-new"))
    }

    func testScrapesThreadIDAndOptionCount() throws {
        let form = try newPollForm()

        XCTAssertEqual(form.threadID, "4115578")
        XCTAssertEqual(form.optionCount, 4)
        XCTAssertNotNil(form.submitButton)
        XCTAssertNotNil(form.updateOptionCountButton)

        // A fresh form starts blank, never-expiring, and single-choice.
        XCTAssertEqual(form.poll.question, "")
        XCTAssertEqual(form.poll.options, ["", "", "", ""])
        XCTAssertFalse(form.poll.allowsMultipleChoice)
        XCTAssertEqual(form.poll.timeoutDays, 0)
    }

    func testRejectsFormThatIsntAPoll() throws {
        let notAPoll = try scrapeForm(matchingSelector: "form[name = 'vbform']", inFixtureNamed: "newthread")
        XCTAssertThrowsError(try NewPollForm(notAPoll))
    }

    /// The load-bearing test: `SubmittableForm.enter(text:for:)` *appends* to whatever the markup
    /// already had, so every text field we fill in has to be cleared first or we send it twice.
    func testSubmissionEntries() throws {
        var form = try newPollForm()
        form.poll = PollSubmission(
            question: "Which is best?",
            options: ["Cats", "Dogs", "Birds"],
            allowsMultipleChoice: true,
            timeoutDays: 7
        )

        let entries = try form.makeSubmittableForm().submit(button: form.submitButton).entries
        func values(_ name: String) -> [String] {
            entries.filter { $0.name == name }.map(\.value)
        }

        // Exactly one value per field, not two.
        XCTAssertEqual(values("question"), ["Which is best?"])
        XCTAssertEqual(values("polloptions"), ["3"])
        XCTAssertEqual(values("timeout"), ["7"])

        XCTAssertEqual(values("options[1]"), ["Cats"])
        XCTAssertEqual(values("options[2]"), ["Dogs"])
        XCTAssertEqual(values("options[3]"), ["Birds"])
        // The form has four slots and we only used three; the spare submits empty.
        XCTAssertEqual(values("options[4]"), [])

        // Hidden fields ride along untouched.
        XCTAssertEqual(values("threadid"), ["4115578"])
        XCTAssertEqual(values("action"), ["postpoll"])

        // Checkboxes: parseurl ships checked, disablesmilies unchecked, multiple as asked.
        XCTAssertEqual(values("parseurl"), ["yes"])
        XCTAssertEqual(values("disablesmilies"), [])
        XCTAssertEqual(values("multiple"), ["yes"])

        // Only the button we submitted with.
        XCTAssertEqual(values("submit"), ["Submit New Poll"])
        XCTAssertEqual(values("preview"), [])
        XCTAssertEqual(values("updatenumber"), [])
    }

    func testSingleChoiceOmitsMultipleCheckbox() throws {
        var form = try newPollForm()
        form.poll = PollSubmission(question: "Yes or no?", options: ["Yes", "No"])

        let entries = try form.makeSubmittableForm().submit(button: form.submitButton).entries
        XCTAssertNil(entries.first { $0.name == "multiple" })
    }

    func testNormalizesBeforeSubmitting() throws {
        var form = try newPollForm()
        form.poll = PollSubmission(
            question: "  Which is best?  ",
            options: ["  Cats  ", "Dogs", "   ", ""],
            timeoutDays: 0
        )

        let entries = try form.makeSubmittableForm().submit(button: form.submitButton).entries
        func value(_ name: String) -> String? { entries.first { $0.name == name }?.value }

        XCTAssertEqual(value("question"), "Which is best?")
        XCTAssertEqual(value("options[1]"), "Cats")
        XCTAssertEqual(value("options[2]"), "Dogs")
        // The blank options were dropped, so only two remain.
        XCTAssertEqual(value("polloptions"), "2")
        XCTAssertNil(value("options[3]"))
    }

    func testRejectsMoreOptionsThanTheFormHasSlots() throws {
        var form = try newPollForm()
        form.poll = PollSubmission(question: "Pick one", options: ["a", "b", "c", "d", "e"])

        XCTAssertThrowsError(try form.makeSubmittableForm())
    }

    func testRejectsInvalidPoll() throws {
        var form = try newPollForm()
        form.poll = PollSubmission(question: "", options: ["a", "b"])
        XCTAssertThrowsError(try form.makeSubmittableForm())

        form.poll = PollSubmission(question: "Only one answer?", options: ["a"])
        XCTAssertThrowsError(try form.makeSubmittableForm())
    }

    func testOptionCountUpdateForm() throws {
        let form = try newPollForm()

        let entries = try form.makeOptionCountUpdateForm(count: 8)
            .submit(button: form.updateOptionCountButton)
            .entries

        XCTAssertEqual(entries.filter { $0.name == "polloptions" }.map(\.value), ["8"])
        XCTAssertEqual(entries.first { $0.name == "updatenumber" }?.value, "Update options")
        XCTAssertNil(entries.first { $0.name == "submit" })
    }
}
