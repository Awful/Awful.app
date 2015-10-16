//  Thread.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

@objc(Thread)
public class Thread: AwfulManagedObject {
    @NSManaged var anyUnreadPosts: Bool
    @NSManaged var archived: Bool
    @NSManaged public var bookmarked: Bool
    @NSManaged var bookmarkListPage: Int32
    @NSManaged public var closed: Bool
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged public var lastPostAuthorName: String?
    @NSManaged public var lastPostDate: NSDate?
    @NSManaged private var primitiveNumberOfPages: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    @NSManaged public var numberOfVotes: Int32
    @NSManaged public var rating: Float32
    @NSManaged private var primitiveSeenPosts: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    @NSManaged private var primitiveStarCategory: NSNumber
    @NSManaged public var sticky: Bool
    @NSManaged public var stickyIndex: Int32
    @NSManaged public var threadID: String
    @NSManaged public var threadListPage: Int32
    @NSManaged public var title: String?
    @NSManaged private var primitiveTotalReplies: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    
    @NSManaged public var author: User?
    @NSManaged public var forum: Forum?
    @NSManaged var posts: NSMutableSet /* Post */
    @NSManaged public var secondaryThreadTag: ThreadTag? /* via secondaryThreads */
    @NSManaged var threadFilters: NSMutableSet /* ThreadFilter */
    @NSManaged public var threadTag: ThreadTag? /* via threads */
}

@objc public enum StarCategory: Int16 {
    case Orange, Red, Yellow, None
}

extension Thread {
    public var beenSeen: Bool {
        return seenPosts > 0
    }
    
    public var numberOfPages: Int32 {
        get {
            willAccessValueForKey("numberOfPages")
            let numberOfPages = primitiveNumberOfPages.intValue
            didAccessValueForKey("numberOfPages")
            return numberOfPages
        }
        set {
            willChangeValueForKey("numberOfPages")
            primitiveNumberOfPages = NSNumber(int: newValue)
            didChangeValueForKey("numberOfPages")
            
            let minimumTotalReplies: Int32 = (newValue - 1) * 40
            if minimumTotalReplies > totalReplies {
                willChangeValueForKey("totalReplies")
                primitiveTotalReplies = NSNumber(int: minimumTotalReplies)
                didChangeValueForKey("totalReplies")
                updateAnyUnreadPosts()
            }
        }
    }
    
    public var seenPosts: Int32 {
        get {
            willAccessValueForKey("seenPosts")
            let seenPosts = primitiveSeenPosts.intValue
            didAccessValueForKey("seenPosts")
            return seenPosts
        }
        set {
            willChangeValueForKey("seenPosts")
            primitiveSeenPosts = NSNumber(int: newValue)
            didChangeValueForKey("seenPosts")
            
            if newValue > totalReplies + 1 {
                totalReplies = newValue - 1
            }
            updateAnyUnreadPosts()
        }
    }
    
    public var starCategory: StarCategory {
        get {
            willAccessValueForKey("starCategory")
            let starCategory = Int16(primitiveStarCategory.integerValue)
            didAccessValueForKey("starCategory")
            return StarCategory(rawValue: starCategory) ?? .None
        }
        set {
            willChangeValueForKey("starCategory")
            primitiveStarCategory = Int(newValue.rawValue)
            didChangeValueForKey("starCategory")
        }
    }
    
    public var totalReplies: Int32 {
        get {
            willAccessValueForKey("totalReplies")
            let totalReplies = primitiveTotalReplies.intValue
            didAccessValueForKey("totalReplies")
            return totalReplies
        }
        set {
            willChangeValueForKey("totalReplies")
            primitiveTotalReplies = NSNumber(int: newValue)
            didChangeValueForKey("totalReplies")
            
            let minimumNumberOfPages = 1 + newValue / 40
            if minimumNumberOfPages > numberOfPages {
                willChangeValueForKey("numberOfPages")
                primitiveNumberOfPages = NSNumber(int: minimumNumberOfPages)
                didChangeValueForKey("numberOfPages")
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
    let threadID: String
    
    public init(threadID: String) {
        assert(!threadID.isEmpty)
        self.threadID = threadID
        super.init(entityName: Thread.entityName())
    }
    
    public required init?(coder: NSCoder) {
        threadID = coder.decodeObjectForKey(threadIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [threadIDKey]
    }
}
private let threadIDKey = "threadID"

extension Thread {
    public override var objectKey: ThreadKey {
        return ThreadKey(threadID: threadID)
    }
}

@objc(ThreadFilter)
class ThreadFilter: AwfulManagedObject {
    @NSManaged var numberOfPages: Int32
    
    @NSManaged var author: User
    @NSManaged var thread: Thread
}

extension Thread {
    public func filteredNumberOfPagesForAuthor(author: User) -> Int32 {
        if let filter = fetchFilter(author: author) {
            return filter.numberOfPages
        } else {
            return 0
        }
    }
    
    public func setFilteredNumberOfPages(numberOfPages: Int32, forAuthor author: User) {
        var filter: ThreadFilter! = fetchFilter(author: author)
        if filter == nil {
            filter = ThreadFilter.insertIntoManagedObjectContext(managedObjectContext!)
            filter.thread = self
            filter.author = author
        }
        filter.numberOfPages = numberOfPages
    }
    
    private func fetchFilter(author author: User) -> ThreadFilter? {
        let request = NSFetchRequest(entityName: ThreadFilter.entityName())
        request.predicate = NSPredicate(format: "thread = %@ AND author = %@", self, author)
        request.fetchLimit = 1
        var results: [ThreadFilter] = []
        var success: Bool = false
        do {
            results = try (managedObjectContext!.executeFetchRequest(request) as! [ThreadFilter])
            success = true
        }
        catch let error as NSError {
            print("error fetching: \(error)")
        }
        assert(success, "error fetching, crashing")
        return results.first
    }
}
