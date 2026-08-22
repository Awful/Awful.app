//  ThreadPoll.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 A poll attached to a thread, as read off a thread page or off `poll.php`.

 This is the *read* side of polls; `PollSubmission` is the request side, used when attaching a poll
 to a thread you're posting.

 The forums render a poll in one of two shapes, and this type covers both because they're the same
 poll at different points in its life:

 - A ballot you can vote on, which carries no vote counts at all.
 - A table of results, which carries no way to vote.

 So `ballot` and the per-option `voteCount`/`percentage` are independently optional. Reach for
 `canVote` and `hasResults` rather than testing them directly.

 - Seealso: `ThreadPollScrapeResult`, which builds one of these out of markup.
 */
public struct ThreadPoll: Equatable, Sendable {

    /**
     Identifies the poll to `poll.php`.

     Optional because the results shape only ever mentions the poll ID in the "Edit Poll (moderators
     only)" link, which regular accounts may well not be served. Results scraped off a thread page
     are complete on their own, so a nil `pollID` costs us only the ability to *re*-fetch them.
     */
    public var pollID: String?

    /// The thread the poll is attached to, when we read it off a thread page.
    ///
    /// Worth keeping because the thread page is the authoritative rendering: it's what the reader
    /// sees, and after voting it's where we go back to for the numbers.
    public var threadID: String?

    /// What people are voting on.
    public var question: String

    /// The answers, in the order the forums listed them. Ballot order and results order agree.
    public var options: [Option]

    /// How many votes were cast, when the forums told us. Note this is not the sum of the options'
    /// vote counts: a multiple-choice poll counts one voter once but their several picks severally.
    public var totalVotes: Int?

    /// Whether the forums said we've already voted on this poll.
    public var hasVoted: Bool

    /// Non-nil exactly when the forums served up something we can vote with.
    public var ballot: Ballot?

    /// The moderators-only "Edit Poll" link, when the page had one.
    public var editURL: URL?

    /// Whether we know how the voting is going.
    public var hasResults: Bool {
        options.contains { $0.voteCount != nil }
    }

    /// Whether we can vote right now. Note that a poll that has closed and a poll we've already
    /// voted on are indistinguishable in the markup; both just show up without a ballot.
    public var canVote: Bool {
        ballot != nil
    }

    public init(
        pollID: String? = nil,
        threadID: String? = nil,
        question: String = "",
        options: [Option] = [],
        totalVotes: Int? = nil,
        hasVoted: Bool = false,
        ballot: Ballot? = nil,
        editURL: URL? = nil
    ) {
        self.pollID = pollID
        self.threadID = threadID
        self.question = question
        self.options = options
        self.totalVotes = totalVotes
        self.hasVoted = hasVoted
        self.ballot = ballot
        self.editURL = editURL
    }

    /// One of the answers on offer.
    public struct Option: Equatable, Identifiable, Sendable {

        /// The forums' own 1-based option number, taken from `optionnumber[3]` on a ballot and from
        /// row order in a results table.
        public var id: Int

        /// The option as text, with any images (i.e. smilies) standing in as their alt text. An
        /// option that's nothing but a smilie would otherwise come out blank. Handy for
        /// accessibility and logging; to actually show the option, use `segments`.
        public var text: String

        /// The option broken into runs of text and images, so smilies can be drawn as smilies.
        public var segments: [Segment]

        /// Nil on a ballot, which doesn't say how anyone voted.
        public var voteCount: Int?

        /// Out of 100. Nil on a ballot.
        public var percentage: Double?

        /// The form control's name, e.g. `optionnumber[3]`. Nil in a results table.
        public var formName: String?

        /// What to submit for this option when it's picked. Nil in a results table.
        public var formValue: String?

        public init(
            id: Int,
            text: String,
            segments: [Segment] = [],
            voteCount: Int? = nil,
            percentage: Double? = nil,
            formName: String? = nil,
            formValue: String? = nil
        ) {
            self.id = id
            self.text = text
            self.segments = segments.isEmpty && !text.isEmpty ? [.text(text)] : segments
            self.voteCount = voteCount
            self.percentage = percentage
            self.formName = formName
            self.formValue = formValue
        }

        /// A run of an option's label.
        public enum Segment: Equatable, Sendable {
            case text(String)
            /// Nearly always a smilie. `alt` is the smilie's text form, e.g. `":q:"`, which is both
            /// the accessible label and the key to look it up in the local smilie store.
            case image(url: URL?, alt: String)
        }
    }

    /// Everything needed to cast a vote.
    public struct Ballot: Equatable, Sendable {

        /// Whether more than one option can be picked. The forums say so by using checkboxes rather
        /// than radio buttons. This lives here rather than on `ThreadPoll` because a results table
        /// gives no hint either way, and a field that's only meaningful half the time is a trap.
        public var allowsMultipleChoice: Bool

        /**
         The form's `action` attribute, verbatim.

         Deliberately a string rather than a `URL`: it's usually the relative `"poll.php"`, and
         `ForumsClient` wants something it can resolve against its own base URL.
         */
        public var actionPath: String

        /// Everything the form ships hidden — `action=pollvote`, `pollid`, and anything the forums
        /// might start adding — copied wholesale so we don't have to guess what matters.
        public var hiddenFields: [HiddenField]

        public init(
            allowsMultipleChoice: Bool,
            actionPath: String = "poll.php",
            hiddenFields: [HiddenField] = []
        ) {
            self.allowsMultipleChoice = allowsMultipleChoice
            self.actionPath = actionPath.isEmpty ? "poll.php" : actionPath
            self.hiddenFields = hiddenFields
        }
    }

    /// A hidden form field to send back untouched.
    public struct HiddenField: Equatable, Sendable {
        public var name: String
        public var value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}
