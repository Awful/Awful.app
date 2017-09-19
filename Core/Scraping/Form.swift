//  Form.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/**
 An HTML form as scraped from markup.

 - Seealso: `SubmittableForm` for assistance submitting an HTML form.
 */
public struct Form: ScrapeResult {

    // MARK: - Properties

    /// All `<input>`, `<select>`, and `<textarea>` elements that can possibly contribute form data, in the order that they should contribute form data.
    public let controls: [Control]

    /// The `enctype` attribute, if specified and valid. Defaults to `.urlencoded`.
    public let encodingType: EncodingType

    /// The form's `method` attribute.
    public let method: Method

    /// The form submission encoding, or `.utf8` if a character encoding cannot be determined.
    public let submissionStringEncoding: String.Encoding

    /// Where to submit the form. Is `nil` when the `url` passed to `init(_:url:)` is `nil`.
    public let submissionURL: URL?


    // MARK: - Types

    public enum Control {

        /// `<input type=checkbox>`
        case checkbox(name: String, value: String, isChecked: Bool, isDisabled: Bool)

        /// `<input type=hidden>`
        case hidden(name: String, value: String, isDisabled: Bool)

        /// `<input type=image>`
        case image(SubmitButton)

        /// `<input type=radio>`
        case radioButton(name: String, value: String, isChecked: Bool, isDisabled: Bool)

        /// `<select multiple>`
        case selectMany(name: String, value: String, isDisabled: Bool, isSelected: Bool)

        /// `<select>`
        case selectOne(name: String, value: String, isDisabled: Bool, isSelected: Bool)

        /// `<input type=submit>`
        case submit(SubmitButton)

        /// `<input type=text>` or `<input>`
        case text(name: String, value: String, isDisabled: Bool)

        /// `<textarea>`
        case textarea(name: String, value: String, isDisabled: Bool)

        public var isDisabled: Bool {
            switch self {
            case .checkbox(name: _, value: _, isChecked: _, isDisabled: let isDisabled),
                 .hidden(name: _, value: _, isDisabled: let isDisabled),
                 .radioButton(name: _, value: _, isChecked: _, isDisabled: let isDisabled),
                 .selectMany(name: _, value: _, isDisabled: let isDisabled, isSelected: _),
                 .selectOne(name: _, value: _, isDisabled: let isDisabled, isSelected: _),
                 .text(name: _, value: _, isDisabled: let isDisabled),
                 .textarea(name: _, value: _, isDisabled: let isDisabled):
                return isDisabled

            case .image(let button), .submit(let button):
                return button.isDisabled
            }
        }

        public var name: String {
            switch self {
            case .checkbox(name: let name, value: _, isChecked: _, isDisabled: _),
                 .hidden(name: let name, value: _, isDisabled: _),
                 .radioButton(name: let name, value: _, isChecked: _, isDisabled: _),
                 .selectMany(name: let name, value: _, isDisabled: _, isSelected: _),
                 .selectOne(name: let name, value: _, isDisabled: _, isSelected: _),
                 .text(name: let name, value: _, isDisabled: _),
                 .textarea(name: let name, value: _, isDisabled: _):
                return name

            case .image(let button), .submit(let button):
                return button.name
            }
        }

        public var value: String {
            switch self {
            case .checkbox(name: _, value: let value, isChecked: _, isDisabled: _),
                 .hidden(name: _, value: let value, isDisabled: _),
                 .radioButton(name: _, value: let value, isChecked: _, isDisabled: _),
                 .selectMany(name: _, value: let value, isDisabled: _, isSelected: _),
                 .selectOne(name: _, value: let value, isDisabled: _, isSelected: _),
                 .text(name: _, value: let value, isDisabled: _),
                 .textarea(name: _, value: let value, isDisabled: _):
                return value

            case .image(let button), .submit(let button):
                return button.value
            }
        }
    }

    public enum EncodingType {

        /// `multipart/form-data`
        case multipart

        /// `text/plain`
        case plain

        /// `application/x-www-form-urlencoded`
        case urlencoded

        public static let `default` = EncodingType.urlencoded
    }

    /// An HTTP method.
    public enum Method {
        case get, post

        public static let `default` = Method.get
    }

    /// Buttons that can be the submitter of a form. The submitter is the only button that contributes to form data.
    public struct SubmitButton {

        /// A submit button can override the form's encoding type by setting a `formenctype` attribute.
        public let encodingType: EncodingType?

        public let isDisabled: Bool

        /// A submit button can override the form's HTTP method by setting a `formmethod` attribute.
        public let method: Method?

        /// The empty string (`""`) if the `<input>` element has no `name` attribute. Since the empty string is not allowed as a form control's name, it is equivalent to a missing `name` attribute.
        public let name: String

        /// A submit button can override the form's `action` by setting a `formaction` attribute.
        public let submissionURL: URL?

        /// The content of the `<input>` element's `value` attribute. If there is no `value` attribute, either the string `"Submit"` (for a plain submit button) or the empty string `""` (for an image button).
        public let value: String
    }

    // MARK: - ScrapeResult

    /**
     - Throws: `ScrapingError` if `html` is not a `form` element.
     */
    public init(_ html: HTMLNode, url: URL?) throws {
        guard let form = html as? HTMLElement, form.tagName.lowercased() == "form" else {
            throw ScrapingError.missingExpectedElement("form")
        }

        controls = form
            .nodes(matchingSelector: "input, select, textarea")
            .flatMap(Control.makeEntries)
        encodingType = (form["enctype"] as String?).flatMap(EncodingType.init) ?? .default
        method = (form["method"] as String?).flatMap(Method.init) ?? .default
        submissionStringEncoding = scrapeSubmissionStringEncoding(document: html.document, form: form) ?? .utf8
        submissionURL = scrapeSubmissionURL(form["action"] ?? "")
    }
}

private extension Form.Control {
    static func makeEntries(from element: HTMLElement) -> [Form.Control] {
        guard let name = element["name"], !name.isEmpty else { return [] }

        let isDisabled = HTMLSelector(string: ":disabled").matchesElement(element)
        let lowercaseType = element["type"]?.lowercased()

        switch (element.tagName, lowercaseType) {
        case ("input", "image"?), ("input", "submit"?):
            let constructor = lowercaseType == "image" ? Form.Control.image : Form.Control.submit
            return [constructor(Form.SubmitButton(
                encodingType: (element["formenctype"] as String?).flatMap(Form.EncodingType.init),
                isDisabled: isDisabled,
                method: (element["formmethod"] as String?).flatMap(Form.Method.init),
                name: name,
                submissionURL: scrapeSubmissionURL(element["formaction"] ?? ""),
                value: lowercaseType == "image" ? "" : "Submit"))]

        case ("input", "checkbox"?):
            return [.checkbox(
                name: name,
                value: element["value"] ?? "on",
                isChecked: element["checked"] != nil,
                isDisabled: isDisabled)]

        case ("input", "radio"?):
            return [.radioButton(
                name: name,
                value: element["value"] ?? "on",
                isChecked: element["checked"] != nil,
                isDisabled: isDisabled)]

        case ("input", _):
            return [.text(name: name, value: element["value"] ?? "", isDisabled: isDisabled)]

        case("select", _):
            func isOptionDisabled(_ option: HTMLElement) -> Bool {
                if option["disabled"] != nil {
                    return true

                }
                if let optgroup = option.parentElement, optgroup.tagName == "optgroup" {
                    return optgroup["disabled"] != nil
                }
                return false
            }

            let constructor = element["multiple"] == nil ? Form.Control.selectOne : Form.Control.selectMany

            return element
                .nodes(matchingSelector: "option")
                .map { constructor(
                    name,
                    $0["value"] ?? $0.textContent,
                    isOptionDisabled($0),
                    $0["selected"] != nil) }

        case ("textarea", _):
            return [.textarea(name: name, value: element.textContent, isDisabled: isDisabled)]

        default:
            return []
        }
    }
}

private extension Form.EncodingType {
    init?(_ string: String) {
        switch string.lowercased() {
        case "application/x-www-form-urlencoded":
            self = .urlencoded
        case "multipart/form-data":
            self = .multipart
        case "text/plain":
            self = .plain
        default:
            return nil
        }
    }
}

private extension Form.Method {
    init?(_ string: String) {
        switch string.lowercased() {
        case "get":
            self = .get
        case "post":
            self = .post
        default:
            return nil
        }
    }
}

private func scrapeSubmissionStringEncoding(document: HTMLDocument?, form: HTMLElement) -> String.Encoding? {
    guard let acceptEncoding = form["accept-charset"] else {
        return (document?.parsedStringEncoding).flatMap(String.Encoding.init)
    }

    return acceptEncoding
        .components(separatedBy: asciiWhitespace)
        .map(StringEncodingForLabel)
        .filter { $0 != InvalidStringEncoding() }
        .flatMap(String.Encoding.init)
        .first
}

private let asciiWhitespace: CharacterSet = ["\u{0009}", "\u{000A}", "\u{000C}", "\u{000D}", "\u{0020}"]

private func scrapeSubmissionURL(_ string: String) -> URL? {
    return URL(string: string.trimmingCharacters(in: asciiWhitespace))
}
