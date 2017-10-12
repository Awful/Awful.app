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
    
    @objc var stylesheet: String {
        guard let URL = Bundle(for: ProfileViewModel.self).url(forResource: "profile.css", withExtension: nil) else { fatalError("missing profile.css") }
        do {
            return try String(contentsOf: URL, encoding: String.Encoding.utf8)
        } catch {
            fatalError("couldn't load \(URL): \(error)")
        }
    }
    
    @objc var userInterfaceIdiom: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "ipad"
        default: return "iphone"
        }
    }
    
    @objc var dark: Bool {
        return AwfulSettings.shared().darkTheme
    }
    
    @objc var regDateFormat: DateFormatter {
        return DateFormatter.regDateFormatter
    }
    
    @objc var lastPostDateFormat: DateFormatter {
        return DateFormatter.postDateFormatter
    }
    
    @objc var anyContactInfo: Bool {
        if privateMessagesWork { return true }
        if let AIM = profile.aimName , !AIM.isEmpty { return true }
        if let ICQ = profile.icqName , !ICQ.isEmpty { return true }
        if let yahoo = profile.yahooName , !yahoo.isEmpty { return true }
        if profile.homepageURL != nil { return true }
        return false
    }
    
    @objc var privateMessagesWork: Bool {
        guard profile.user.canReceivePrivateMessages else { return false }
        return AwfulSettings.shared().canSendPrivateMessages
    }
    
    @objc var customTitleHTML: String? {
        guard let HTML = profile.user.customTitleHTML , HTML != "<br/>" else { return nil }
        return HTML
    }
    
    @objc var gender: String? {
        return profile.gender ?? "porpoise"
    }
    
    @objc var avatarURL: URL? {
        return profile.user.avatarURL as URL?
    }
    
    @objc var regdate: Date? {
        return profile.user.regdate as Date?
    }
    
    @objc var username: String? {
        return profile.user.username
    }
    
    @objc var aboutMe: String? {
        return profile.aboutMe
    }
    
    @objc var aimName: String? {
        return profile.aimName
    }
    
    @objc var homepageURL: URL? {
        return profile.homepageURL as URL?
    }
    
    @objc var icqName: String? {
        return profile.icqName
    }
    
    @objc var interests: String? {
        return profile.interests
    }
    
    @objc var lastPost: Date? {
        return profile.lastPostDate as Date?
    }
    
    @objc var location: String? {
        return profile.location
    }
    
    @objc var occupation: String? {
        return profile.occupation
    }
    
    @objc var postCount: Int32 {
        return profile.postCount
    }
    
    @objc var postRate: String? {
        return profile.postRate
    }
    
    @objc var profilePictureURL: URL? {
        return profile.profilePictureURL as URL?
    }
    
    @objc var yahooName: String? {
        return profile.yahooName
    }
}
