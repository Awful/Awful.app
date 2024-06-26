//  AuthorPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension AuthorSidebarScrapeResult {
    func update(_ user: User) {
        if isAdministrator != user.administrator { user.administrator = isAdministrator }
        if customTitle != user.customTitleHTML { user.customTitleHTML = customTitle }
        if isModerator != user.moderator { user.moderator = isModerator }
        if let regdate = regdate, user.regdate != regdate { user.regdate = regdate }
        if let regdateRaw = regdateRaw, user.regdateRaw != regdateRaw { user.regdateRaw = regdateRaw }
        if userID.rawValue != user.userID { user.userID = userID.rawValue }
        if !username.isEmpty, username != user.username { user.username = username }

        var allAuthorClasses = additionalAuthorClasses
        if isAdministrator { allAuthorClasses.insert("role-admin") }
        if isModerator { allAuthorClasses.insert("role-mod") }
        let authorClasses = allAuthorClasses.sorted().joined(separator: " ")
        if authorClasses != user.authorClasses { user.authorClasses = authorClasses }
    }

    func upsert(into context: NSManagedObjectContext) throws -> User {
        let users = User.fetch(in: context) {
            var subs: [NSPredicate] = [.init("\(\User.userID) = \(userID.rawValue)")]
            if !username.isEmpty {
                subs.append(.init("\(\User.username) = \(username)"))
            }
            $0.predicate = .or(subs)
            $0.relationshipKeyPathsForPrefetching = [#keyPath(User.profile)]
            $0.returnsObjectsAsFaults = false
        }

        let user = users.isEmpty ? User.insert(into: context) : merge(users)
        update(user)
        return user
    }
}

/// Merges to-many relationships into the first user in the array, then deletes all but the first user.
func merge(_ users: [User]) -> User {
    precondition(!users.isEmpty)
    let user = users.dropFirst().reduce(users[0]) { (winner, donor) in
        for post in donor.posts {
            winner.posts.insert(post)
        }
        for message in donor.receivedPrivateMessages {
            winner.receivedPrivateMessages.insert(message)
        }
        for message in donor.sentPrivateMessages {
            winner.sentPrivateMessages.insert(message)
        }
        for filter in donor.threadFilters {
            winner.threadFilters.insert(filter)
        }
        for thread in donor.threads {
            winner.threads.insert(thread)
        }
        return winner
    }

    users.dropFirst().forEach { $0.managedObjectContext?.delete($0) }

    return user
}
