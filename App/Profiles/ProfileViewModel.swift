//  ProfileViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

final class ProfileViewModel: NSObject {
    private let profile: Profile
    
    init(profile: Profile) {
        self.profile = profile
        super.init()
    }
    
    var stylesheet: String {
        guard let URL = NSBundle(forClass: ProfileViewModel.self).URLForResource("profile.css", withExtension: nil) else { fatalError("missing profile.css") }
        do {
            return try String(contentsOfURL: URL, encoding: NSUTF8StringEncoding)
        } catch {
            fatalError("couldn't load \(URL): \(error)")
        }
    }
    
    var userInterfaceIdiom: String {
        switch UIDevice.currentDevice().userInterfaceIdiom {
        case .Pad: return "ipad"
        default: return "iphone"
        }
    }
    
    var dark: Bool {
        return AwfulSettings.sharedSettings().darkTheme
    }
    
    var regDateFormat: NSDateFormatter {
        return NSDateFormatter.regDateFormatter()
    }
    
    var lastPostDateFormat: NSDateFormatter {
        return NSDateFormatter.postDateFormatter()
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
        return AwfulSettings.sharedSettings().canSendPrivateMessages
    }
    
    var customTitleHTML: String? {
        guard let HTML = profile.user.customTitleHTML , HTML != "<br/>" else { return nil }
        return HTML
    }
    
    var gender: String? {
        return profile.gender ?? "porpoise"
    }
    
    var avatarURL: NSURL? {
        return profile.user.avatarURL
    }
    
    var regdate: NSDate? {
        return profile.user.regdate
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
    
    var homepageURL: NSURL? {
        return profile.homepageURL
    }
    
    var icqName: String? {
        return profile.icqName
    }
    
    var interests: String? {
        return profile.interests
    }
    
    var lastPost: NSDate? {
        return profile.lastPostDate
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
    
    var profilePictureURL: NSURL? {
        return profile.profilePictureURL
    }
    
    var yahooName: String? {
        return profile.yahooName
    }
}
