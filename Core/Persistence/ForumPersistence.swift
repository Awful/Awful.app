//  ForumPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension ForumBreadcrumb {
    func update(_ forum: Forum) {
        if id.rawValue != forum.forumID { forum.forumID = id.rawValue }
        if name != forum.name { forum.name = name }
    }

    func update(_ group: ForumGroup) {
        if id.rawValue != group.groupID { group.groupID = id.rawValue }
        if name != group.name { group.name = name }
    }

    func upsert(into context: NSManagedObjectContext) throws -> ForumGroup {
        let request = NSFetchRequest<ForumGroup>(entityName: ForumGroup.entityName())
        request.predicate = NSPredicate(format: "%K = %@", #keyPath(ForumGroup.groupID), id.rawValue)
        request.returnsObjectsAsFaults = false

        let group = try context.fetch(request).first
            ?? ForumGroup.insertIntoManagedObjectContext(context: context)

        update(group)

        return group
    }
}

internal extension ForumBreadcrumbsScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> (group: ForumGroup?, forums: [Forum]) {
        let group = try self.forums.first.map { try $0.upsert(into: context) as ForumGroup }

        let rawForums = self.forums.dropFirst()
        let rawForumIDs = rawForums.map { $0.id.rawValue }
        let request = NSFetchRequest<Forum>(entityName: Forum.entityName())
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(Forum.forumID), rawForumIDs)
        request.returnsObjectsAsFaults = false

        var unorderedForums: [ForumID: Forum] = [:]
        for forum in try context.fetch(request) {
            guard let id = ForumID(rawValue: forum.forumID) else { continue }
            unorderedForums[id] = forum
        }

        for rawForum in rawForums where unorderedForums[rawForum.id] == nil {
            let forum = Forum.insertIntoManagedObjectContext(context: context)
            forum.forumID = rawForum.id.rawValue
            unorderedForums[rawForum.id] = forum
        }

        let forums = rawForums.flatMap { (raw) -> Forum? in
            let forum = unorderedForums[raw.id]
            if let forum = forum { raw.update(forum) }
            return forum
        }

        if forums.first?.parentForum != nil { forums.first?.parentForum = nil }
        for (parent, child) in zip(forums, forums.dropFirst()) {
            if parent != child.parentForum { child.parentForum = parent }
        }

        for forum in forums {
            if group != forum.group { forum.group = group }
        }

        return (group: group, forums: forums)
    }
}
