//  Forum+Presentation.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

extension Forum {
    var ancestors: AnySequence<Forum> {
        var current = parentForum
        return AnySequence {
            return AnyIterator {
                let next = current
                current = current?.parentForum
                return next
            }
        }
    }
}

extension Forum {
    func tickleForFetchedResultsController() {
        let index = self.index
        self.index = index
    }
}

extension Forum {
    func collapse() {
        metadata.showsChildrenInForumList = false
        tickleForFetchedResultsController()
        
        var subforumStack = Array(childForums)
        while let forum = subforumStack.popLast() {
            subforumStack.append(contentsOf: forum.childForums)
            
            forum.metadata.visibleInForumList = false
            forum.tickleForFetchedResultsController()
        }
    }
    
    func expand() {
        metadata.showsChildrenInForumList = true
        tickleForFetchedResultsController()
        
        var subforumStack = Array(childForums)
        while let forum = subforumStack.popLast() {
            if forum.metadata.showsChildrenInForumList {
                subforumStack.append(contentsOf: forum.childForums)
            }
            
            forum.metadata.visibleInForumList = true
            forum.tickleForFetchedResultsController()
        }
    }

    func toggleCollapseExpand() {
        if metadata.showsChildrenInForumList {
            collapse()
        } else {
            expand()
        }
    }
}

extension Forum {
    func addFavorite() {
        metadata.favorite = true
        metadata.favoriteIndex = Forum.nextFavoriteIndex(in: managedObjectContext!)

        tickleForFetchedResultsController()
    }

    func removeFavorite() {
        metadata.favorite = false

        tickleForFetchedResultsController()
    }

    func toggleFavorite() {
        if metadata.favorite {
            removeFavorite()
        } else {
            addFavorite()
        }
    }

    private static func nextFavoriteIndex(in managedObjectContext: NSManagedObjectContext) -> Int32 {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ForumMetadata.entityName())
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [#keyPath(ForumMetadata.favoriteIndex)]
        request.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: false)]
        request.fetchLimit = 1
        let results = try! managedObjectContext.fetch(request) as? [[String: Any]]
        let currentHighest = results?.first?[#keyPath(ForumMetadata.favoriteIndex)] as? Int32 ?? 0
        return currentHighest + 1
    }
}
