//  Forum+Presentation.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

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
}
