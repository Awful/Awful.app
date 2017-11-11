//  SubmittableForm.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 Provides a mutable interface to a `Form`.

 Keeps track of text entry and checking/unchecking/selecting/deselecting form controls, then prepares the form data set for submission.

 Attempts to follow https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#form-submission-2.
 */
public final class SubmittableForm {
    private let form: Form
    private var enteredText: [String: [String]] = [:]
    private var selectedValues: [String: Set<String>] = [:]

    public enum Error: Swift.Error {
        case missingControl(type: String, named: String)
    }

    public struct PreparedSubmission {
        public let encodingType: Form.EncodingType
        public let entries: [Entry]
        public let method: Form.Method
        public let submissionStringEncoding: String.Encoding
        public let submissionURL: URL?

        public typealias Entry = (name: String, value: String)
    }

    public init(_ form: Form) {
        self.form = form

        for control in form.controls {
            switch control {
            case .checkbox(name: let name, value: let value, isChecked: let isSelected, isDisabled: let isDisabled) where isSelected && !isDisabled,
                 .selectMany(name: let name, value: let value, isDisabled: let isDisabled, isSelected: let isSelected) where isSelected && !isDisabled:
                _select(value: value, for: name, allowsMultiple: true)

            case .radioButton(name: let name, value: let value, isChecked: let isSelected, isDisabled: let isDisabled) where isSelected && !isDisabled,
                 .selectOne(name: let name, value: let value, isDisabled: let isDisabled, isSelected: let isSelected) where isSelected && !isDisabled:
                _select(value: value, for: name, allowsMultiple: false)

            case .text(name: let name, value: let value, isDisabled: let isDisabled) where !isDisabled:
                _append(text: value, for: name, needsLineBreakNormalization: false)

            case .textarea(name: let name, value: let value, isDisabled: let isDisabled) where !isDisabled:
                _append(text: value, for: name, needsLineBreakNormalization: true)

            case .checkbox, .radioButton, .selectMany, .selectOne, .text, .textarea:
                break

            case .file, .hidden, .submit:
                break
            }
        }
    }

    /**
     Set the text value for a text field or text box in the form.
     
     Note that multiple controls can have the same name. Each call to `enter(text:for:)` adds another entry for the name; if you want to be sure there's only one entry, call `clearText(for:)` before calling `enter(text:for:)`.
     */
    public func enter(text: String, for name: String) throws {
        guard let control = form.controls.first(where: { control in
            switch control {
            case .text, .textarea:
                return !control.isDisabled && control.name == name
            case .checkbox, .file, .hidden, .radioButton, .selectMany, .selectOne, .submit:
                return false
            }
        }) else {
            throw Error.missingControl(type: "text, textarea", named: name)
        }
        
        if case .textarea = control {
            _append(text: text, for: name, needsLineBreakNormalization: true)
        }
        else {
            _append(text: text, for: name, needsLineBreakNormalization: false)
        }
    }
    
    private func _append(text: String, for name: String, needsLineBreakNormalization: Bool) {
        enteredText[name, default: []] += { () -> [String] in
            if needsLineBreakNormalization {
                return [textareaValueTransform.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: "\r\n")]
            }
            else {
                return [text]
            }
            }()
    }
    
    public func clearText(for name: String) throws {
        guard form.controls.contains(where: { control in
            switch control {
            case .text, .textarea:
                return !control.isDisabled && control.name == name
            case .checkbox, .file, .hidden, .radioButton, .selectMany, .selectOne, .submit:
                return false
            }
        }) else {
            throw Error.missingControl(type: "text, textarea", named: name)
        }
        
        enteredText.removeValue(forKey: name)
    }

    public func select(value: String, for name: String) throws {
        guard let control = form.controls.first(where: isSelectable(name: name, value: value)) else {
            throw Error.missingControl(type: "checkbox, radio, select", named: name)
        }

        switch control {
        case .checkbox, .selectMany:
            _select(value: value, for: name, allowsMultiple: true)

        case .radioButton, .selectOne:
            _select(value: value, for: name, allowsMultiple: false)

        case .file, .hidden, .submit, .text, .textarea:
            fatalError("controls of this type type should not make it this far: \(control)")
        }
    }

    private func _select(value: String, for name: String, allowsMultiple: Bool) {
        if allowsMultiple {
            selectedValues[name, default: []].insert(value)
        }
        else {
            selectedValues[name] = [value]
        }
    }

    public func deselect(value: String, for name: String) throws {
        guard let control = form.controls.first(where: isSelectable(name: name, value: value)) else {
            throw Error.missingControl(type: "checkbox, radio, select", named: name)
        }

        switch control {
        case .checkbox, .selectMany:
            selectedValues[name]?.remove(value)
        case .radioButton, .selectOne:
            break
        case .file, .hidden, .submit, .text, .textarea:
            fatalError("controls of this type type should not make it this far: \(control)")
        }
    }

    public func submit(button submitButton: Form.SubmitButton?) -> PreparedSubmission {
        // https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-form-data-set
        
        var entries: [PreparedSubmission.Entry] = []
        var enteredTextControlNames: Set<String> = []

        for control in form.controls {
            guard !control.isDisabled else { continue }

            switch control {
            case .checkbox(name: let name, value: let value, isChecked: _, isDisabled: _),
                 .radioButton(name: let name, value: let value, isChecked: _, isDisabled: _),
                 .selectMany(name: let name, value: let value, isDisabled: _, isSelected: _),
                 .selectOne(name: let name, value: let value, isDisabled: _, isSelected: _):
                guard selectedValues[name]?.contains(value) == true else { break }
                entries.append((name: name, value: value))

            case .file:
                break

            case .hidden(name: let name, value: let value, isDisabled: _):
                entries.append((name: name, value: value))

            case .submit(let button):
                guard button == submitButton else { break }

                switch button.kind {
                case .image:
                    let nameX = control.name.isEmpty ? "x" : control.name + ".x"
                    let nameY = control.name.isEmpty ? "y" : control.name + ".y"
                    entries.append((name: nameX, value: "0"))
                    entries.append((name: nameY, value: "0"))

                case .plain:
                    guard !control.name.isEmpty else { break }
                    entries.append((name: control.name, value: control.value))
                }

            case .text(name: let name, value: _, isDisabled: _),
                 .textarea(name: let name, value: _, isDisabled: _):
                guard !enteredTextControlNames.contains(name) else { break }
                enteredTextControlNames.insert(name)
                
                guard let values = enteredText[name] else { break }
                entries.append(contentsOf: values.map { (name: name, value: $0) })
            }
        }

        return PreparedSubmission(
            encodingType: submitButton?.encodingType ?? form.encodingType,
            entries: entries,
            method: submitButton?.method ?? form.method,
            submissionStringEncoding: form.submissionStringEncoding,
            submissionURL: submitButton?.submissionURL ?? form.submissionURL)
    }
}

private func isSelectable(name: String, value: String) -> (_ control: Form.Control) -> Bool {
    return { control in
        switch control {
        case .checkbox, .radioButton, .selectMany, .selectOne:
            return !control.isDisabled && control.name == name && control.value == value
        case .file, .hidden, .submit, .text, .textarea:
            return false
        }
    }
}

private let textareaValueTransform = try! NSRegularExpression(pattern: "\\r(?!\\n)|(?<!\\r)\\n")
