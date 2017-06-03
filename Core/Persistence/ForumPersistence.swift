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

internal extension ForumHierarchyNode {
    func update(_ forum: Forum) {
        if id.rawValue != forum.forumID { forum.forumID = id.rawValue }
        if name != forum.name { forum.name = name }
    }

    func update(_ group: ForumGroup) {
        if id.rawValue != group.groupID { group.groupID = id.rawValue }
        if name != group.name { group.name = name }
    }
}

internal extension ForumHierarchyScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [Forum] {
        let rawGroups = nodes.filter { $0.depth == 0 }
        var existingGroups: [ForumID: ForumGroup] = [:]
        do {
            let request = NSFetchRequest<ForumGroup>(entityName: ForumGroup.entityName())
            let groupIDs = rawGroups.map { $0.id.rawValue }
            request.predicate = NSPredicate(format: "%K in %@", #keyPath(ForumGroup.groupID), groupIDs)
            request.returnsObjectsAsFaults = false

            for group in try context.fetch(request) {
                guard let id = ForumID(rawValue: group.groupID) else { continue }
                existingGroups[id] = group
            }
        }

        let groups = rawGroups.enumerated().map { i, raw -> ForumGroup in
            let group = existingGroups[raw.id] ?? ForumGroup.insertIntoManagedObjectContext(context: context)
            raw.update(group)
            if i != Int(group.index) { group.index = Int32(i) }
            return group
        }

        let rawForums = nodes.filter { $0.depth > 0 }
        var unorderedForums: [ForumID: Forum] = [:]
        do {
            let request = NSFetchRequest<Forum>(entityName: Forum.entityName())
            let forumIDs = rawForums.map { $0.id.rawValue }
            request.predicate = NSPredicate(format: "%K in %@", #keyPath(Forum.forumID), forumIDs)
            request.returnsObjectsAsFaults = false

            for forum in try context.fetch(request) {
                guard let id = ForumID(rawValue: forum.forumID) else { continue }
                unorderedForums[id] = forum
            }
        }

        let forums = rawForums.enumerated().map { i, raw -> Forum in
            let forum = unorderedForums[raw.id] ?? Forum.insertIntoManagedObjectContext(context: context)
            raw.update(forum)
            if i != Int(forum.index) { forum.index = Int32(i) }
            return forum
        }

        var currentGroup: ForumGroup?
        var forumStack: [Forum] = []
        var groupIterator = groups.makeIterator()
        var forumIterator = forums.makeIterator()
        for node in nodes {
            while node.depth <= forumStack.count, !forumStack.isEmpty {
                _ = forumStack.popLast()
            }

            if node.depth == 0 {
                currentGroup = groupIterator.next()

                assert(currentGroup?.groupID == node.id.rawValue, "mismatched group while constructing forum hierarchy")
            }
            else if let forum = forumIterator.next() {
                assert(forum.forumID == node.id.rawValue, "mismatched forum ID while constructing forum hierarchy")

                if currentGroup != forum.group { forum.group = currentGroup }

                let parentForum = forumStack.last
                if parentForum != forum.parentForum { forum.parentForum = parentForum }

                forumStack.append(forum)
            }
        }

        return forums
    }
}
