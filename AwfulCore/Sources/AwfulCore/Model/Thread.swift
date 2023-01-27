//  Thread.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

@objc(Thread)
public class AwfulThread: AwfulManagedObject, Managed {
    public static var entityName: String { "Thread" }

    @NSManaged public var anyUnreadPosts: Bool
    @NSManaged var archived: Bool
    @NSManaged public var bookmarked: Bool
    @NSManaged public var bookmarkListPage: Int32
    @NSManaged public var closed: Bool
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged public var lastPostAuthorName: String?
    @NSManaged public var lastPostDate: NSDate?
    @NSManaged internal var primitiveNumberOfPages: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    @NSManaged public var numberOfVotes: Int32
    @NSManaged public var rating: Float32
    @NSManaged internal var primitiveSeenPosts: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    @NSManaged internal var primitiveStarCategory: NSNumber
    @NSManaged public var sticky: Bool
    @NSManaged public var ratingImageBasename: String?
    @NSManaged public var stickyIndex: Int32
    @NSManaged public var threadID: String
    @NSManaged public var threadListPage: Int32
    @NSManaged public var title: String?
    @NSManaged internal var primitiveTotalReplies: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    
    @NSManaged public var author: User?
    @NSManaged public var forum: Forum?
    @NSManaged var posts: Set<Post>
    @NSManaged public var secondaryThreadTag: ThreadTag? /* via secondaryThreads */
    @NSManaged var threadFilters: Set<ThreadFilter>
    @NSManaged public var threadTag: ThreadTag? /* via threads */
    
    // support for answering polls and viewing results
    @NSManaged public var pollID: String?
    @NSManaged public var pollHTML: String?
    
    public override var objectKey: ThreadKey { .init(threadID: threadID) }
}

@objc public enum StarCategory: Int16, CaseIterable {
    case orange = 0
    case red = 1
    case yellow = 2

    case none = 3 // probably should've been 0, oh well

    case teal = 4
    case green = 5
    case purple = 6
}

extension AwfulThread {
    public var beenSeen: Bool {
        return seenPosts > 0
    }
    
    public var numberOfPages: Int32 {
        get {
            willAccessValue(forKey: "numberOfPages")
            let numberOfPages = primitiveNumberOfPages.int32Value
            didAccessValue(forKey: "numberOfPages")
            return numberOfPages
        }
        set {
            willChangeValue(forKey: "numberOfPages")
            primitiveNumberOfPages = NSNumber(value: newValue)
            didChangeValue(forKey: "numberOfPages")
            
            let minimumTotalReplies = (newValue - 1) * 40
            if minimumTotalReplies > totalReplies {
                willChangeValue(forKey: "totalReplies")
                primitiveTotalReplies = NSNumber(value: minimumTotalReplies)
                didChangeValue(forKey: "totalReplies")
                updateAnyUnreadPosts()
            }
        }
    }
    
    public var seenPosts: Int32 {
        get {
            willAccessValue(forKey: "seenPosts")
            let seenPosts = primitiveSeenPosts.int32Value
            didAccessValue(forKey: "seenPosts")
            return seenPosts
        }
        set {
            willChangeValue(forKey: "seenPosts")
            primitiveSeenPosts = NSNumber(value: newValue)
            didChangeValue(forKey: "seenPosts")
            
            if newValue > totalReplies + 1 {
                totalReplies = newValue - 1
            }
            updateAnyUnreadPosts()
        }
    }
    
    public var starCategory: StarCategory {
        get {
            willAccessValue(forKey: "starCategory")
            let starCategory = primitiveStarCategory.int16Value
            didAccessValue(forKey: "starCategory")
            return StarCategory(rawValue: starCategory) ?? .none
        }
        set {
            willChangeValue(forKey: "starCategory")
            primitiveStarCategory = NSNumber(value: newValue.rawValue)
            didChangeValue(forKey: "starCategory")
        }
    }
    
    public var totalReplies: Int32 {
        get {
            willAccessValue(forKey: "totalReplies")
            let totalReplies = primitiveTotalReplies.int32Value
            didAccessValue(forKey: "totalReplies")
            return totalReplies
        }
        set {
            willChangeValue(forKey: "totalReplies")
            primitiveTotalReplies = NSNumber(value: newValue)
            didChangeValue(forKey: "totalReplies")
            
            let minimumNumberOfPages = 1 + newValue / 40
            if minimumNumberOfPages > numberOfPages {
                willChangeValue(forKey: "numberOfPages")
                primitiveNumberOfPages = NSNumber(value: minimumNumberOfPages)
                didChangeValue(forKey: "numberOfPages")
            }
            updateAnyUnreadPosts()
        }
    }
    
    private func updateAnyUnreadPosts() {
        anyUnreadPosts = seenPosts > 0 && unreadPosts > 0
    }
    
    public var unreadPosts: Int32 {
        return totalReplies + 1 - seenPosts
    }
}

@objc(ThreadKey)
public final class ThreadKey: AwfulObjectKey {
    @objc let threadID: String
    
    public init(threadID: String) {
        assert(!threadID.isEmpty)
        self.threadID = threadID
        super.init(entityName: AwfulThread.entityName)
    }
    
    public required init?(coder: NSCoder) {
        threadID = coder.decodeObject(forKey: threadIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [threadIDKey]
    }
}
private let threadIDKey = "threadID"

@objc(ThreadFilter)
class ThreadFilter: AwfulManagedObject, Managed {
    static var entityName: String { "ThreadFilter" }

    @NSManaged var numberOfPages: Int32
    
    @NSManaged var author: User
    @NSManaged var thread: AwfulThread
}

extension AwfulThread {
    public func filteredNumberOfPagesForAuthor(_ author: User) -> Int32 {
        ThreadFilter.findOrFetch(
            in: managedObjectContext!,
            matching: filterPredicate(author: author)
        )?.numberOfPages ?? 0
    }
    
    public func setFilteredNumberOfPages(
        _ numberOfPages: Int32,
        forAuthor author: User
    ) {
        let filter = ThreadFilter.findOrCreate(
            in: managedObjectContext!,
            matching: filterPredicate(author: author),
            configure: {
                $0.thread = self
                $0.author = author
            }
        )
        filter.numberOfPages = numberOfPages
    }

    private func filterPredicate(author: User) -> NSPredicate {
        .and(
            .init("\(\ThreadFilter.thread) = \(self)"),
            .init("\(\ThreadFilter.author) = \(author)")
        )
    }
}
