//
//  ProfilePersistence.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import CoreData

internal extension ProfileScrapeResult {
    func update(_ profile: Profile) {
        if about.rawValue != profile.aboutMe { profile.aboutMe = about.rawValue }
        if aimName != profile.aimName { profile.aimName = aimName }
        if gender != profile.gender { profile.gender = gender }
        if homepage != profile.homepageURL as URL? { profile.homepageURL = homepage as NSURL? }
        if icqName != profile.icqName { profile.icqName = icqName }
        if interests != profile.interests { profile.interests = interests }
        if lastPostDate != profile.lastPostDate as Date? { profile.lastPostDate = lastPostDate as NSDate? }
        if location != profile.location { profile.location = location }
        if occupation != profile.occupation { profile.occupation = occupation }
        if let postCount = postCount, postCount != Int(profile.postCount) { profile.postCount = Int32(postCount) }
        if postRate != profile.postRate { profile.postRate = postRate }
        if profilePicture != profile.profilePictureURL as URL? { profile.profilePictureURL = profilePicture as NSURL? }
        if yahooName != profile.yahooName { profile.yahooName = yahooName }
    }

    func upsert(into context: NSManagedObjectContext) throws -> Profile {
        let user = try author.upsert(into: context)
        if canReceivePrivateMessages != user.canReceivePrivateMessages { user.canReceivePrivateMessages = canReceivePrivateMessages }

        let profile: Profile = {
            if let profile = user.profile { return profile }
            let newProfile = Profile.insertIntoManagedObjectContext(context: context)
            user.profile = newProfile
            return newProfile
        }()

        update(profile)

        return profile
    }
}
