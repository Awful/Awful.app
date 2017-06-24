//  AuthorPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension AuthorSidebarScrapeResult {
    func update(_ user: User) {
        if isAdministrator != user.administrator { user.administrator = isAdministrator }
        if customTitle != user.customTitleHTML { user.customTitleHTML = customTitle }
        if isModerator != user.moderator { user.moderator = isModerator }
        if let regdate = regdate, user.regdate as Date? != regdate { user.regdate = regdate as NSDate }
        if userID.rawValue != user.userID { user.userID = userID.rawValue }
        if !username.isEmpty, username != user.username { user.username = username }

        var allAuthorClasses = additionalAuthorClasses
        if isAdministrator { allAuthorClasses.insert("role-admin") }
        if isModerator { allAuthorClasses.insert("role-mod") }
        let authorClasses = allAuthorClasses.sorted().joined(separator: " ")
        if authorClasses != user.authorClasses { user.authorClasses = authorClasses }
    }

    func upsert(into context: NSManagedObjectContext) throws -> User {
        let request = NSFetchRequest<User>(entityName: User.entityName())

        request.predicate = {
            var subpredicates: [NSPredicate] = [
                NSPredicate(format: "%K = %@", #keyPath(User.userID), userID.rawValue)]
            if !username.isEmpty {
                subpredicates.append(NSPredicate(format: "%K = %@", #keyPath(User.username), username))
            }
            return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        }()

        request.relationshipKeyPathsForPrefetching = [#keyPath(User.profile)]
        request.returnsObjectsAsFaults = false

        let users = try context.fetch(request)
        let user = users.isEmpty ? User.insertIntoManagedObjectContext(context: context) : merge(users)

        update(user)

        return user
    }
}


/// Merges to-many relationships into the first user in the array, then deletes all but the first user.
internal func merge(_ users: [User]) -> User {
    precondition(!users.isEmpty)
    let user = users.dropFirst().reduce(users[0]) { (winner, donor) in
        donor.posts.forEach(winner.posts.add)
        donor.receivedPrivateMessages.forEach(winner.receivedPrivateMessages.add)
        donor.sentPrivateMessages.forEach(winner.sentPrivateMessages.add)
        donor.threadFilters.forEach(winner.threadFilters.add)
        donor.threads.forEach(winner.threads.add)
        return winner
    }

    users.dropFirst().forEach { $0.managedObjectContext?.delete($0) }

    return user
}
