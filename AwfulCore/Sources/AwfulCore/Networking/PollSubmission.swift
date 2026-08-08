//  PollSubmission.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 A poll the user wants to attach to a thread they're posting.

 This is the *request* side of polls. Reading an existing poll out of a thread is a separate type
 (there isn't one yet).

 - Seealso: `NewPollForm`, which turns one of these into something submittable to `poll.php`.
 */
public struct PollSubmission: Equatable, Codable, Sendable {

    /// The question people are voting on. At most `maximumQuestionLength` characters.
    public var question: String

    /// The answers people can pick from. Between `optionCountRange.lowerBound` and
    /// `optionCountRange.upperBound` of them, once blank ones are dropped.
    public var options: [String]

    /// Whether people can pick more than one option.
    public var allowsMultipleChoice: Bool

    /// Days during which people can vote. Zero means the poll never closes.
    public var timeoutDays: Int

    /// The forums truncate anything longer (the `question` field is `maxlength=85`).
    public static let maximumQuestionLength = 85

    /// The forums cap polls at 25 options, and a poll needs at least two to be a poll.
    public static let optionCountRange = 2...25

    public init(
        question: String = "",
        options: [String] = ["", ""],
        allowsMultipleChoice: Bool = false,
        timeoutDays: Int = 0
    ) {
        self.question = question
        self.options = options
        self.allowsMultipleChoice = allowsMultipleChoice
        self.timeoutDays = timeoutDays
    }

    /// Trims whitespace off the question and every option, and drops options that were blank.
    public var normalized: PollSubmission {
        var copy = self
        copy.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.options = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return copy
    }

    /// - Throws: `ValidationError` if the poll isn't something the forums would accept.
    public func validate() throws {
        let poll = normalized

        guard !poll.question.isEmpty else {
            throw ValidationError.emptyQuestion
        }
        guard poll.question.count <= Self.maximumQuestionLength else {
            throw ValidationError.questionTooLong(maximum: Self.maximumQuestionLength)
        }
        guard poll.options.count >= Self.optionCountRange.lowerBound else {
            throw ValidationError.tooFewOptions(minimum: Self.optionCountRange.lowerBound)
        }
        guard poll.options.count <= Self.optionCountRange.upperBound else {
            throw ValidationError.tooManyOptions(maximum: Self.optionCountRange.upperBound)
        }
        guard poll.timeoutDays >= 0 else {
            throw ValidationError.negativeTimeout
        }
    }

    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }

    public enum ValidationError: LocalizedError, Equatable {
        case emptyQuestion
        case questionTooLong(maximum: Int)
        case tooFewOptions(minimum: Int)
        case tooManyOptions(maximum: Int)
        case negativeTimeout

        public var errorDescription: String? {
            switch self {
            case .emptyQuestion:
                String(localized: "Please ask a question.", bundle: .module)
            case .questionTooLong(let maximum):
                String(localized: "A poll question can be at most \(maximum) characters.", bundle: .module)
            case .tooFewOptions(let minimum):
                String(localized: "A poll needs at least \(minimum) options.", bundle: .module)
            case .tooManyOptions(let maximum):
                String(localized: "A poll can have at most \(maximum) options.", bundle: .module)
            case .negativeTimeout:
                String(localized: "A poll can't run for a negative number of days.", bundle: .module)
            }
        }
    }
}
