//  PollSubmissionTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PollSubmissionTests: XCTestCase {

    func testNormalizationTrimsAndDropsBlanks() {
        let poll = PollSubmission(
            question: "  Best pet?\n",
            options: ["  Cats", "Dogs  ", "   ", "", "\t\n"]
        ).normalized

        XCTAssertEqual(poll.question, "Best pet?")
        XCTAssertEqual(poll.options, ["Cats", "Dogs"])
    }

    func testValidPoll() {
        XCTAssertTrue(PollSubmission(question: "Best pet?", options: ["Cats", "Dogs"]).isValid)
    }

    func testEmptyQuestion() {
        assertInvalid(
            PollSubmission(question: "   ", options: ["Cats", "Dogs"]),
            .emptyQuestion
        )
    }

    func testQuestionTooLong() {
        let tooLong = String(repeating: "x", count: PollSubmission.maximumQuestionLength + 1)
        assertInvalid(
            PollSubmission(question: tooLong, options: ["Cats", "Dogs"]),
            .questionTooLong(maximum: PollSubmission.maximumQuestionLength)
        )

        let justRight = String(repeating: "x", count: PollSubmission.maximumQuestionLength)
        XCTAssertTrue(PollSubmission(question: justRight, options: ["Cats", "Dogs"]).isValid)
    }

    func testTooFewOptions() {
        assertInvalid(
            PollSubmission(question: "Best pet?", options: ["Cats"]),
            .tooFewOptions(minimum: 2)
        )
        // Blank options don't count toward the minimum.
        assertInvalid(
            PollSubmission(question: "Best pet?", options: ["Cats", "  "]),
            .tooFewOptions(minimum: 2)
        )
    }

    func testTooManyOptions() {
        let options = (1...26).map { "Option \($0)" }
        assertInvalid(
            PollSubmission(question: "Best pet?", options: options),
            .tooManyOptions(maximum: 25)
        )

        XCTAssertTrue(PollSubmission(question: "Best pet?", options: Array(options.prefix(25))).isValid)
    }

    func testNegativeTimeout() {
        assertInvalid(
            PollSubmission(question: "Best pet?", options: ["Cats", "Dogs"], timeoutDays: -1),
            .negativeTimeout
        )
    }

    func testRoundTripsThroughJSON() throws {
        let poll = PollSubmission(
            question: "Best pet?",
            options: ["Cats", "Dogs"],
            allowsMultipleChoice: true,
            timeoutDays: 3
        )
        let data = try JSONEncoder().encode(poll)
        XCTAssertEqual(try JSONDecoder().decode(PollSubmission.self, from: data), poll)
    }

    private func assertInvalid(
        _ poll: PollSubmission,
        _ expected: PollSubmission.ValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(poll.isValid, file: file, line: line)
        XCTAssertThrowsError(try poll.validate(), file: file, line: line) { error in
            XCTAssertEqual(error as? PollSubmission.ValidationError, expected, file: file, line: line)
        }
    }
}
