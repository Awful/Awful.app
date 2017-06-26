//  AnnouncementPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension AnnouncementListScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [AwfulCore.Announcement] {
        let existingAnnouncements: [AwfulCore.Announcement]
        do {
            let request = NSFetchRequest<AwfulCore.Announcement>(entityName: AwfulCore.Announcement.entityName())
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AwfulCore.Announcement.listIndex), ascending: true)]
            request.returnsObjectsAsFaults = false
            existingAnnouncements = try context.fetch(request)
        }

        var users: [String: User] = [:]
        do {
            let request = NSFetchRequest<User>(entityName: User.entityName())
            let usernames = self.announcements
                .flatMap { $0.author?.username }
                .filter { !$0.isEmpty }
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(User.username), usernames)
            request.returnsObjectsAsFaults = false
            for user in try context.fetch(request) {
                guard let username = user.username else { continue }
                users[username] = user
            }
        }

        var announcements: [AwfulCore.Announcement] = []

        // Since announcements don't have IDs, there's not much we can do beyond going in list order and hoping for the best.
        for (existing, scraped) in zip(existingAnnouncements, self.announcements) {
            scraped.update(existing)

            // Announcements have an author sidebar, but there's no user ID. Also the custom title seems to be rendered differently, so we shouldn't take it as gospel.
            if let author = scraped.author, let user = users[author.username] {
                if
                    !author.customTitle.isEmpty,
                    user.customTitleHTML == nil || user.customTitleHTML?.isEmpty == true
                {
                    user.customTitleHTML = author.customTitle
                }
                if let regdate = author.regdate, regdate != user.regdate { user.regdate = regdate }
            }

            announcements.append(existing)
        }

        for toDelete in existingAnnouncements.dropFirst(self.announcements.count) {
            context.delete(toDelete)
        }

        return announcements
    }
}

private extension AnnouncementListScrapeResult.Announcement {
    func update(_ announcement: AwfulCore.Announcement) {
        if let author = author {
            if author.customTitle != announcement.authorCustomTitleHTML { announcement.authorCustomTitleHTML = author.customTitle }
            if let regdate = author.regdate, regdate != announcement.authorRegdate { announcement.authorRegdate = regdate }
            if !author.username.isEmpty, author.username != announcement.authorUsername { announcement.authorUsername = author.username }
        }
        if !body.isEmpty, body != announcement.bodyHTML { announcement.bodyHTML = body }
        if let date = date, date != announcement.postedDate { announcement.postedDate = date }
    }
}

internal extension ThreadListScrapeResult {
    func upsertAnnouncements(into context: NSManagedObjectContext) throws -> [AwfulCore.Announcement] {
        var threadTags: [String: ThreadTag] = [:]
        do {
            let request = NSFetchRequest<ThreadTag>(entityName: ThreadTag.entityName())
            let imageNames = self.announcements.flatMap { $0.iconURL }.flatMap(ThreadTag.imageName)
            request.predicate = NSPredicate(format: "%K in %@", #keyPath(ThreadTag.imageName), imageNames)
            request.returnsObjectsAsFaults = false

            for tag in try context.fetch(request) {
                guard let imageName = tag.imageName else { continue }
                threadTags[imageName] = tag
            }
        }

        var users: [UserID: User] = [:]
        do {
            let request = NSFetchRequest<User>(entityName: User.entityName())
            let userIDs = self.announcements.flatMap { $0.author }.map { $0.rawValue }
            request.predicate = NSPredicate(format: "%K in %@", #keyPath(User.userID), userIDs)
            request.returnsObjectsAsFaults = false

            for user in try context.fetch(request) {
                guard let userID = UserID(rawValue: user.userID) else { continue }
                users[userID] = user
            }
        }

        let existingAnnouncements: [AwfulCore.Announcement]
        do {
            let request = NSFetchRequest<AwfulCore.Announcement>(entityName: AwfulCore.Announcement.entityName())
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AwfulCore.Announcement.listIndex), ascending: true)]
            existingAnnouncements = try context.fetch(request)
        }

        var announcements: [AwfulCore.Announcement] = []

        for (existing, scraped) in zip(existingAnnouncements, self.announcements) {
            let announcement = existing
            scraped.update(announcement)

            if let author = scraped.author {
                let user = users[author] ?? User.insertIntoManagedObjectContext(context: context)
                if author.rawValue != user.userID { user.userID = author.rawValue }
                if !scraped.authorUsername.isEmpty, scraped.authorUsername != user.username { user.username = scraped.authorUsername }
                users[author] = user
                if user != announcement.author { announcement.author = user }
            }

            if
                let imageName = scraped.iconURL.map(ThreadTag.imageName),
                imageName != announcement.threadTag?.imageName
            {
                let threadTag = threadTags[imageName] ?? ThreadTag.insertIntoManagedObjectContext(context: context)
                if imageName != threadTag.imageName { threadTag.imageName = imageName }
                threadTags[imageName] = threadTag
                announcement.threadTag = threadTag
            }

            announcements.append(announcement)
        }

        for toDelete in existingAnnouncements.dropFirst(self.announcements.count) {
            context.delete(toDelete)
        }

        var listIndex = existingAnnouncements.count
        for new in self.announcements.dropFirst(existingAnnouncements.count) {
            let announcement = AwfulCore.Announcement.insertIntoManagedObjectContext(context: context)
            new.update(announcement)

            announcement.listIndex = Int32(listIndex)
            listIndex += 1

            if let author = new.author {
                let user = users[author] ?? User.insertIntoManagedObjectContext(context: context)
                if author.rawValue != user.userID { user.userID = author.rawValue }
                if !new.authorUsername.isEmpty, new.authorUsername != user.username { user.username = new.authorUsername }
                users[author] = user
                announcement.author = user
            }

            if let imageName = new.iconURL.map(ThreadTag.imageName) {
                let threadTag = threadTags[imageName] ?? ThreadTag.insertIntoManagedObjectContext(context: context)
                if imageName != threadTag.imageName { threadTag.imageName = imageName }
                threadTags[imageName] = threadTag
                announcement.threadTag = threadTag
            }
            
            announcements.append(announcement)
        }
        
        return announcements
    }
}

private extension ThreadListScrapeResult.Announcement {
    func update(_ announcement: Announcement) {
        if let lastUpdated = lastUpdated, lastUpdated != announcement.postedDate { announcement.postedDate = lastUpdated }
        if !title.isEmpty, title != announcement.title {
            announcement.title = title

            // Title mismatch probably means the announcement body has changed, possibly because it's a different announcement than the last time we scraped.
            announcement.bodyHTML = ""
        }
    }
}
