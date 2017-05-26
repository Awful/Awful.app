//
//  ProfilePersistence.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import CoreData

extension ProfileScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> Profile {
        let request = NSFetchRequest<User>(entityName: User.entityName())

        request.predicate = {
            var subpredicates: [NSPredicate] = []
            if !userID.isEmpty {
                subpredicates.append(NSPredicate(format: "%K = %@", #keyPath(User.userID), userID.rawValue))
            }
            if !username.isEmpty {
                subpredicates.append(NSPredicate(format: "%K = %@", #keyPath(User.username), username))
            }
            return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        }()

        request.relationshipKeyPathsForPrefetching = [#keyPath(User.profile)]
        request.returnsObjectsAsFaults = false

        let users = try context.fetch(request)
        let user = users.isEmpty ? User.insertIntoManagedObjectContext(context: context) : merge(users)

        if isAdministrator != user.administrator { user.administrator = isAdministrator }
        if canReceivePrivateMessages != user.canReceivePrivateMessages { user.canReceivePrivateMessages = canReceivePrivateMessages }
        if customTitle.rawValue != user.customTitleHTML { user.customTitleHTML = customTitle.rawValue }
        if isModerator != user.moderator { user.moderator = isModerator }
        if let regdate = regdate, user.regdate as Date? != regdate { user.regdate = regdate as NSDate }
        if !userID.isEmpty, userID.rawValue != user.userID { user.userID = userID.rawValue }
        if !username.isEmpty, username != user.username { user.username = username }

        var allAuthorClasses = additionalAuthorClasses
        if isAdministrator { allAuthorClasses.insert("role-admin") }
        if isModerator { allAuthorClasses.insert("role-mod") }
        let authorClasses = allAuthorClasses.sorted().joined(separator: " ")
        if authorClasses != user.authorClasses { user.authorClasses = authorClasses }


        let profile: Profile = {
            if let profile = user.profile { return profile }
            let newProfile = Profile.insertIntoManagedObjectContext(context: context)
            user.profile = newProfile
            return newProfile
        }()

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

        return profile
    }
}

/// Merges to-many relationships into the first user in the array.
private func merge(_ users: [User]) -> User {
    precondition(!users.isEmpty)
    return users.dropFirst().reduce(users[0]) { (winner, donor) in
        donor.posts.forEach(winner.posts.add)
        donor.receivedPrivateMessages.forEach(winner.receivedPrivateMessages.add)
        donor.sentPrivateMessages.forEach(winner.sentPrivateMessages.add)
        donor.threadFilters.forEach(winner.threadFilters.add)
        donor.threads.forEach(winner.threads.add)
        return winner
    }
}
