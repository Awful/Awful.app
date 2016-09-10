//  ForumTweaks.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ForumTweaks: NSObject {
    let postButton: String?
    let autocorrectionType: UITextAutocorrectionType
    let autocapitalizationType: UITextAutocapitalizationType
    let spellCheckingType: UITextSpellCheckingType
    let showRatings: Bool
    let showRatingsAsThreadTags: Bool
    
    fileprivate init(dictionary: [String: AnyObject]) {
        postButton = dictionary["postButton"] as? String
        
        if let correction = dictionary["autocorrection"] as? Bool {
            autocorrectionType = UITextAutocorrectionType(correction)
        } else {
            autocorrectionType = .default
        }
        
        if let capitalization = dictionary["autocapitalization"] as? Bool {
            autocapitalizationType = UITextAutocapitalizationType(capitalization)
        } else {
            autocapitalizationType = .sentences
        }
        
        if let spellChecking = dictionary["checkSpelling"] as? Bool {
            spellCheckingType = UITextSpellCheckingType(spellChecking)
        } else {
            spellCheckingType = .default
        }
        
        showRatings = dictionary["showRatings"] as? Bool ?? true
        showRatingsAsThreadTags = dictionary["showRatingsAsThreadTags"] as? Bool ?? false
        
        super.init()
    }
}

private extension UITextAutocorrectionType {
    init(_ bool: Bool) {
        self = bool ? .yes : .no
    }
}

private extension UITextAutocapitalizationType {
    init(_ bool: Bool) {
        self = bool ? .sentences : .none
    }
}

private extension UITextSpellCheckingType {
    init(_ bool: Bool) {
        self = bool ? .yes : .no
    }
}

private let tweaks: [String: [String: AnyObject]] = {
    guard let URL = Bundle(for: ForumTweaks.self).url(forResource: "ForumTweaks.plist", withExtension: nil) else {
        fatalError("missing ForumTweaks.plist")
    }
    guard let dict = NSDictionary(contentsOf: URL) as? [String: [String: AnyObject]] else {
        fatalError("unexpected hierarchy in ForumTweaks.plist")
    }
    return dict
}()

extension ForumTweaks {
    convenience init?(forumID: String) {
        let dict = tweaks[forumID] ?? [:]
        self.init(dictionary: dict)
    }
}
