//  ProfileViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

final class ProfileViewModel: NSObject {
    fileprivate let profile: Profile
    
    init(profile: Profile) {
        self.profile = profile
        super.init()
    }
    
    var stylesheet: String {
        guard let URL = Bundle(for: ProfileViewModel.self).url(forResource: "profile.css", withExtension: nil) else { fatalError("missing profile.css") }
        do {
            return try String(contentsOf: URL, encoding: String.Encoding.utf8)
        } catch {
            fatalError("couldn't load \(URL): \(error)")
        }
    }
    
    var userInterfaceIdiom: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "ipad"
        default: return "iphone"
        }
    }
    
    var dark: Bool {
        return AwfulSettings.shared().darkTheme
    }
    
    var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter()
    }
    
    var lastPostDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter()
    }
    
    var anyContactInfo: Bool {
        if privateMessagesWork { return true }
        if let AIM = profile.aimName , !AIM.isEmpty { return true }
        if let ICQ = profile.icqName , !ICQ.isEmpty { return true }
        if let yahoo = profile.yahooName , !yahoo.isEmpty { return true }
        if profile.homepageURL != nil { return true }
        return false
    }
    
    var privateMessagesWork: Bool {
        guard profile.user.canReceivePrivateMessages else { return false }
        return AwfulSettings.shared().canSendPrivateMessages
    }
    
    var customTitleHTML: String? {
        guard let HTML = profile.user.customTitleHTML , HTML != "<br/>" else { return nil }
        return HTML
    }
    
    var gender: String? {
        return profile.gender ?? "porpoise"
    }
    
    var avatarURL: URL? {
        return profile.user.avatarURL as URL?
    }
    
    var regdate: Date? {
        return profile.user.regdate as Date?
    }
    
    var username: String? {
        return profile.user.username
    }
    
    var aboutMe: String? {
        return profile.aboutMe
    }
    
    var aimName: String? {
        return profile.aimName
    }
    
    var homepageURL: URL? {
        return profile.homepageURL as URL?
    }
    
    var icqName: String? {
        return profile.icqName
    }
    
    var interests: String? {
        return profile.interests
    }
    
    var lastPost: Date? {
        return profile.lastPostDate as Date?
    }
    
    var location: String? {
        return profile.location
    }
    
    var occupation: String? {
        return profile.occupation
    }
    
    var postCount: Int32 {
        return profile.postCount
    }
    
    var postRate: String? {
        return profile.postRate
    }
    
    var profilePictureURL: URL? {
        return profile.profilePictureURL as URL?
    }
    
    var yahooName: String? {
        return profile.yahooName
    }
}
