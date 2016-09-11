//  AwfulCore.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

extension AwfulThread {
    static func bookmarksFetchRequest(_ sortedByUnread: Bool) -> NSFetchRequest<AwfulThread> {
        let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
        fetchRequest.fetchBatchSize = 20
        fetchRequest.predicate = NSPredicate(format: "bookmarked = YES AND bookmarkListPage > 0")
        
        var sortDescriptors = [NSSortDescriptor(key: "bookmarkListPage", ascending: true)]
        if sortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        
        return fetchRequest
    }
    
    static func threadsFetchRequest(_ forum: Forum, sortedByUnread: Bool, filterThreadTag: ThreadTag?) -> NSFetchRequest<AwfulThread> {
        let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
        fetchRequest.fetchBatchSize = 20
        
        let basePredicate = NSPredicate(format: "threadListPage > 0 AND forum == %@", forum)
        if let threadTag = filterThreadTag {
            let morePredicate = NSPredicate(format: "threadTag == %@", threadTag)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, morePredicate])
        } else {
            fetchRequest.predicate = basePredicate
        }
        
        var sortDescriptors = [
            NSSortDescriptor(key: "stickyIndex", ascending: true),
            NSSortDescriptor(key: "threadListPage", ascending: true)]
        if sortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        
        return fetchRequest
    }
}
