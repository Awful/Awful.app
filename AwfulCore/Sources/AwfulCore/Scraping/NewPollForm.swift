//  NewPollForm.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 The "Post New Poll" form served by `poll.php`, which is where the forums send you after posting a
 thread with `postpoll=yes`.

 Note that the thread is already live by the time this form shows up; adding the poll is a separate
 second step that can fail on its own.
 */
public struct NewPollForm {
    private let form: Form

    /// The thread this poll gets attached to.
    public let threadID: String

    /// How many `options[n]` fields the form actually has. Filling in more than this many options
    /// requires asking the forums for a bigger form first; see `makeOptionCountUpdateForm(count:)`.
    public let optionCount: Int

    /// The poll to submit. Modifications are represented in the form returned by
    /// `makeSubmittableForm()`.
    public var poll: PollSubmission

    public var submitButton: Form.SubmitButton? {
        form.submitButton(named: "submit")
    }

    /// Where the form posts. Read from the form's `action` attribute — which can be `poll.php`,
    /// `/poll.php`, or fully qualified — rather than assumed.
    public var actionPath: String {
        form.submissionURL?.relativeString ?? "poll.php"
    }

    /// Submitting with this button reloads the form with a different number of option fields.
    public var updateOptionCountButton: Form.SubmitButton? {
        form.submitButton(named: "updatenumber")
    }

    /// - Throws: `ScrapingError` if `form` does not appear to be a new poll form.
    public init(_ form: Form) throws {
        self.form = form

        let actions = form.controls.filter { $0.name == hiddenActionInput.name }
        guard actions.contains(where: { $0.value == hiddenActionInput.value }) else {
            throw ScrapingError.missingExpectedElement("input[name = 'action'][value = 'postpoll']")
        }

        guard form.controls.contains(where: { isTextField($0) && $0.name == questionName }) else {
            throw ScrapingError.missingExpectedElement("input[name = '\(questionName)']")
        }

        guard let threadIDControl = form.controls.first(where: { $0.name == threadIDName }) else {
            throw ScrapingError.missingExpectedElement("input[name = '\(threadIDName)']")
        }
        threadID = threadIDControl.value

        optionCount = form.controls
            .filter { isTextField($0) && optionIndex(forControlNamed: $0.name) != nil }
            .count
        guard optionCount > 0 else {
            throw ScrapingError.missingExpectedElement("input[name = 'options[1]']")
        }

        poll = PollSubmission(
            question: form.controls.first { isTextField($0) && $0.name == questionName }?.value ?? "",
            options: (1...optionCount).map { index in
                form.controls.first { isTextField($0) && $0.name == optionName(index) }?.value ?? ""
            },
            allowsMultipleChoice: form.controls.contains { control in
                if case .checkbox(let name, _, let isChecked, let isDisabled) = control {
                    return name == multipleChoiceName && isChecked && !isDisabled
                }
                return false
            },
            timeoutDays: form.controls
                .first { isTextField($0) && $0.name == timeoutName }
                .flatMap { Int($0.value) } ?? 0
        )
    }

    /**
     Returns a form prepared to post `poll`.

     - Throws: `SubmittableForm.Error` if the form is missing a control we expect, or
       `PollSubmission.ValidationError` if `poll` isn't something the forums would accept.
     */
    public func makeSubmittableForm() throws -> SubmittableForm {
        let poll = poll.normalized
        try poll.validate()

        // Not a scrape failure: the caller asked for more options than this form has slots (e.g.
        // the site clamped an option-count update), so report it as a validation problem.
        guard poll.options.count <= optionCount else {
            throw PollSubmission.ValidationError.tooManyOptions(maximum: optionCount)
        }

        let submittable = SubmittableForm(form)

        // `SubmittableForm.init` seeds every text control with the value that's already in the
        // markup, and `enter(text:for:)` *appends* rather than replaces. Without these
        // `clearText(for:)` calls we'd send two values for each of these names.
        try submittable.clearText(for: questionName)
        try submittable.enter(text: poll.question, for: questionName)

        try submittable.clearText(for: optionCountName)
        try submittable.enter(text: "\(poll.options.count)", for: optionCountName)

        try submittable.clearText(for: timeoutName)
        try submittable.enter(text: "\(poll.timeoutDays)", for: timeoutName)

        for index in 1...optionCount {
            let name = optionName(index)
            try submittable.clearText(for: name)
            // Any slots past the end of `poll.options` submit empty, which the forums ignore.
            if index <= poll.options.count {
                try submittable.enter(text: poll.options[index - 1], for: name)
            }
        }

        // `parseurl` ships checked and `disablesmilies` ships unchecked, and `SubmittableForm.init`
        // carries both states forward, so neither needs touching here.
        if poll.allowsMultipleChoice, let value = form.checkboxValue(named: multipleChoiceName) {
            try submittable.select(value: value, for: multipleChoiceName)
        }

        return submittable
    }

    /**
     Returns a form that, when submitted with `updateOptionCountButton`, reloads this form with
     `count` option fields.
     */
    public func makeOptionCountUpdateForm(count: Int) throws -> SubmittableForm {
        let submittable = SubmittableForm(form)
        try submittable.clearText(for: optionCountName)
        try submittable.enter(text: "\(count)", for: optionCountName)
        return submittable
    }

}


private let hiddenActionInput = (name: "action", value: "postpoll")
private let threadIDName = "threadid"
private let questionName = "question"
private let optionCountName = "polloptions"
private let timeoutName = "timeout"
private let multipleChoiceName = "multiple"

private func optionName(_ index: Int) -> String {
    "options[\(index)]"
}

/// The 1-based index in `options[3]`, or nil if `name` isn't a poll option at all.
private func optionIndex(forControlNamed name: String) -> Int? {
    guard name.hasPrefix("options["), name.hasSuffix("]") else { return nil }
    return Int(name.dropFirst("options[".count).dropLast())
}

private func isTextField(_ control: Form.Control) -> Bool {
    switch control {
    case .text:
        return true

    case .checkbox, .file, .hidden, .radioButton, .selectMany, .selectOne, .submit, .textarea:
        return false
    }
}
