//  IgnoreListForm.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Scrapes the ignore list form adds/removes usernames to/from the list.
public struct IgnoreListForm {
    private let form: Form
    
    /// The usernames in the list when the form was scraped. May be empty, indicating that the user ignores nobody.
    public let initialUsernames: [String]
    
    /// The usernames currently in the ignore list. Modifications are represented in the form returned by `makeSubmittableForm()`.
    public var usernames: [String]
    
    public var submitButton: Form.SubmitButton? {
        return form.submitButton(named: "submit")
    }
    
    /// - Throws: `ScrapingError` if `form` does not appear to be an ignore list.
    public init(_ form: Form) throws {
        self.form = form
        
        let userlists = form.controls.filter { $0.name == hiddenIgnoreListInput.name }
        guard userlists.first(where: { $0.value == hiddenIgnoreListInput.value }) != nil else {
            throw ScrapingError.missingExpectedElement("input[name = 'userlist'][value = 'ignore']")
        }
        
        let usernameTextFields = form.controls
            .filter(isTextField)
            .filter { $0.name == usernameTextboxName }
        
        guard !usernameTextFields.isEmpty else {
            throw ScrapingError.missingExpectedElement("input[name = '\(usernameTextboxName)']")
        }
        
        initialUsernames = usernameTextFields
            .filter { !$0.value.isEmpty }
            .map { $0.value }
        
        usernames = initialUsernames
    }
    
    /**
     Returns a submittable form prepared with the current list of `usernames` on this ignore list.
     
     The returned form is submittable as-is, but feel free to modify it as suits your needs.
     
     - Throws: `SubmittableForm.Error`.
     */
    public func makeSubmittableForm() throws -> SubmittableForm {
        let submittable = SubmittableForm(form)
        
        try submittable.clearText(for: usernameTextboxName)
        
        for username in usernames {
            try submittable.enter(text: username, for: usernameTextboxName)
        }
        
        return submittable
    }
}


// `IgnoreListForm` basically encapsulates these nuggets of info here.
private let hiddenIgnoreListInput = (name: "userlist", value: "ignore")
private let usernameTextboxName = "listbits[]"


private func isTextField(_ control: Form.Control) -> Bool {
    switch control {
    case .text:
        return true
        
    case .checkbox, .file, .hidden, .radioButton, .selectMany, .selectOne, .submit, .textarea:
        return false
    }
}
