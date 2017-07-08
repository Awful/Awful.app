//  User+Presentation.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

extension User {

    /// Returns a list of author roles for VoiceOver, e.g. "ik" becomes "internet knight".
    func accessibilityRoles(in announcement: Announcement) -> [String] {
        return roles(in: announcement)
            .map { spokenAccessibilityRoles[$0] ?? $0 }
    }

    /// Returns list of author roles for an HTML class attribute, e.g. "ik", "op".
    func roles(in announcement: Announcement) -> [String] {
        var roles = (authorClasses ?? "").components(separatedBy: .whitespacesAndNewlines)
        if announcement.author == self {
            roles.append("op")
        }
        return roles
    }
}

private let spokenAccessibilityRoles: [String: String] = [
    "ik": "internet knight",
    "op": "original poster"]
