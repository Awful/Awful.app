//  ProfileViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Mustache

struct ProfileViewModel: MustacheBoxable {
    private let dict: [String: Any]
    
    init(_ profile: Profile) {
        var privateMessagesWork: Bool {
            guard profile.user.canReceivePrivateMessages else { return false }
            return AwfulSettings.shared().canSendPrivateMessages
        }
        var anyContactInfo: Bool {
            if privateMessagesWork { return true }
            if let aim = profile.aimName, !aim.isEmpty { return true }
            if let icq = profile.icqName, !icq.isEmpty { return true }
            if let yahoo = profile.yahooName, !yahoo.isEmpty { return true }
            if profile.homepageURL != nil { return true }
            return false
        }
        var customTitleHTML: String? {
            guard let html = profile.user.customTitleHTML, html != "<br/>" else { return nil }
            return html
        }

        dict = [
            "aboutMe": profile.aboutMe as Any,
            "aimName": profile.aimName as Any,
            "anyContactInfo": anyContactInfo,
            "avatarURL": profile.user.avatarURL as Any,
            "customTitleHTML": customTitleHTML as Any,
            "dark": AwfulSettings.shared().darkTheme,
            "gender": profile.gender ?? "porpoise",
            "homepageURL": profile.homepageURL as Any,
            "icqName": profile.icqName as Any,
            "interests": profile.interests as Any,
            "lastPost": profile.lastPostDate as Any,
            "location": profile.location as Any,
            "occupation": profile.occupation as Any,
            "postCount": Int(profile.postCount),
            "postRate": profile.postRate as Any,
            "privateMessagesWork": privateMessagesWork,
            "profilePictureURL": profile.profilePictureURL as Any,
            "regdate": profile.user.regdate as Any,
            "stylesheet": loadStylesheet(),
            "username": profile.user.username as Any,
            "yahooName": profile.yahooName as Any]
    }

    var mustacheBox: MustacheBox {
        return Box(dict)
    }
}

private class BundleLocator {}

private func loadStylesheet() -> String {
    guard let url = Bundle(for: BundleLocator.self)
        .url(forResource: "profile.css", withExtension: nil)
        else { fatalError("missing profile.css") }

    do {
        return try String(contentsOf: url, encoding: String.Encoding.utf8)
    } catch {
        fatalError("couldn't load \(url): \(error)")
    }
}
