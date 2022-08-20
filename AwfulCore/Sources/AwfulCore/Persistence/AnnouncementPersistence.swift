//  AnnouncementPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

private let Log = Logger.get()

extension AnnouncementListScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [AwfulCore.Announcement] {
        let existingAnnouncements = AwfulCore.Announcement.fetch(in: context) {
            $0.sortDescriptors = [.init(key: #keyPath(AwfulCore.Announcement.listIndex), ascending: true)]
            $0.returnsObjectsAsFaults = false
        }

        let users = Dictionary(
            User.fetch(in: context) { request in
                let usernames = self.announcements
                    .compactMap { $0.author?.username }
                    .filter { !$0.isEmpty }
                request.predicate = .init("\(\User.username) in \(usernames)")
                request.returnsObjectsAsFaults = false
            }.map { ($0.username!, $0) },
            uniquingKeysWith: { $1 })

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
                if let regdateRaw = author.regdateRaw, regdateRaw != user.regdateRaw { user.regdateRaw = regdateRaw }
            }

            announcements.append(existing)
        }

        for toDelete in existingAnnouncements.dropFirst(self.announcements.count) {
            context.delete(toDelete)
        }

        // No IDs means we don't really know what's been seen except by content. So if there's any new content, assume it hasn't been seen.
        for announcement in announcements {
            if announcement.hasBeenSeen, announcement.contentDidChange {
                Log.d("marking announcement as new because of changed attributes: \(announcement.changedValues().keys.joined(separator: ", "))")

                announcement.hasBeenSeen = false
            }
        }

        return announcements
    }
}

private extension AnnouncementListScrapeResult.Announcement {
    func update(_ announcement: AwfulCore.Announcement) {
        if let author = author {
            if author.customTitle != announcement.authorCustomTitleHTML { announcement.authorCustomTitleHTML = author.customTitle }
            if let regdate = author.regdate, regdate != announcement.authorRegdate { announcement.authorRegdate = regdate }
            if let regdateRaw = author.regdateRaw, regdateRaw != announcement.authorRegdateRaw { announcement.authorRegdateRaw = regdateRaw }
            if !author.username.isEmpty, author.username != announcement.authorUsername { announcement.authorUsername = author.username }
        }
        if !body.isEmpty, body != announcement.bodyHTML { announcement.bodyHTML = body }
        if let date = date, date != announcement.postedDate { announcement.postedDate = date }
        if let dateRaw = dateRaw, dateRaw != announcement.postedDateRaw { announcement.postedDateRaw = dateRaw }
    }
}

extension ThreadListScrapeResult {
    func upsertAnnouncements(
        into context: NSManagedObjectContext
    ) throws -> [AwfulCore.Announcement] {
        var threadTags = Dictionary(
            ThreadTag.fetch(in: context) { request in
                let imageNames = self.announcements
                    .compactMap { $0.iconURL }
                    .flatMap(ThreadTag.imageName)
                request.predicate = .init("\(\ThreadTag.imageName) in \(imageNames)")
                request.returnsObjectsAsFaults = false
            }.map { ($0.imageName!, $0) },
            uniquingKeysWith: { $1 }
        )

        var users = Dictionary(
            User.fetch(in: context) { request in
                let userIDs = self.announcements
                    .compactMap { $0.author }
                    .map { $0.rawValue }
                request.predicate = .init("\(\User.userID) in \(userIDs)")
                request.returnsObjectsAsFaults = false
            }.map { (UserID(rawValue: $0.userID)!, $0) },
            uniquingKeysWith: { $1 }
        )

        let existingAnnouncements = AwfulCore.Announcement.fetch(in: context) {
            $0.sortDescriptors = [.init(key: #keyPath(AwfulCore.Announcement.listIndex), ascending: true)]
        }

        var announcements: [AwfulCore.Announcement] = []

        for (existing, scraped) in zip(existingAnnouncements, self.announcements) {
            let announcement = existing
            scraped.update(announcement)

            if let author = scraped.author {
                let user = users[author] ?? User.insert(into: context)
                if author.rawValue != user.userID { user.userID = author.rawValue }
                if !scraped.authorUsername.isEmpty, scraped.authorUsername != user.username { user.username = scraped.authorUsername }
                users[author] = user
                if user != announcement.author { announcement.author = user }
            }

            if
                let imageName = scraped.iconURL.map(ThreadTag.imageName),
                imageName != announcement.threadTag?.imageName
            {
                let threadTag = threadTags[imageName] ?? ThreadTag.insert(into: context)
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
            let announcement = AwfulCore.Announcement.insert(into: context)
            new.update(announcement)

            announcement.listIndex = Int32(listIndex)
            listIndex += 1

            if let author = new.author {
                let user = users[author] ?? User.insert(into: context)
                if author.rawValue != user.userID { user.userID = author.rawValue }
                if !new.authorUsername.isEmpty, new.authorUsername != user.username { user.username = new.authorUsername }
                users[author] = user
                announcement.author = user
            }

            if let imageName = new.iconURL.map(ThreadTag.imageName) {
                let threadTag = threadTags[imageName] ?? ThreadTag.insert(into: context)
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

            Log.d("announcement title mismatch, assuming it's a different announcement and clearing the body HTML")
            announcement.bodyHTML = ""
        }
    }
}
