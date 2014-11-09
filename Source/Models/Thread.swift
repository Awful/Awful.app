//  Thread.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(Thread)
class Thread: AwfulManagedObject {

    @NSManaged var anyUnreadPosts: Bool
    @NSManaged var archived: Bool
    @NSManaged var bookmarked: Bool
    @NSManaged var closed: Bool
    @NSManaged var hideFromList: Bool
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged private var primitiveLastModifiedDate: NSDate?
    @NSManaged var lastPostAuthorName: String?
    @NSManaged var lastPostDate: NSDate?
    @NSManaged var numberOfPages: Int32
    @NSManaged var numberOfVotes: Int32
    @NSManaged var rating: Float32
    @NSManaged private var primitiveSeenPosts: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    @NSManaged var starCategory: Int16
    @NSManaged var sticky: Bool
    @NSManaged var stickyIndex: Int32
    @NSManaged var threadID: String
    @NSManaged var title: String?
    @NSManaged private var primitiveTotalReplies: NSNumber // Would prefer Int32 but that throws EXC_BAD_ACCESS.
    
    @NSManaged var author: User?
    @NSManaged var forum: Forum?
    @NSManaged var posts: NSMutableSet /* Post */
    @NSManaged var secondaryThreadTag: ThreadTag? /* via secondaryThreads */
    @NSManaged var threadFilters: NSMutableSet /* ThreadFilter */
    @NSManaged var threadTag: ThreadTag? /* via threads */
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        primitiveLastModifiedDate = NSDate()
    }
}

extension Thread {
    var beenSeen: Bool {
        get { return seenPosts > 0 }
    }
    
    var seenPosts: Int32 {
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
            anyUnreadPosts = unreadPosts > 0
        }
    }
    
    var totalReplies: Int32 {
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
            numberOfPages = max(numberOfPages, minimumNumberOfPages)
            anyUnreadPosts = unreadPosts > 0
        }
    }
    
    var unreadPosts: Int32 {
        return totalReplies + 1 - seenPosts
    }
}

extension Thread {
    func filteredNumberOfPagesForAuthor(author: User) -> Int32 {
        let predicate = NSPredicate(format: "thread = %@ AND author = %@", self, author)
        if let filter = ThreadFilter.fetchArbitraryInManagedObjectContext(managedObjectContext!, matchingPredicate: predicate) {
            return filter.numberOfPages
        } else {
            return 0
        }
    }
    
    func setFilteredNumberOfPages(numberOfPages: Int32, forAuthor author: User) {
        let predicate = NSPredicate(format: "thread = %@ AND author = %@", self, author)
        var filter = ThreadFilter.fetchArbitraryInManagedObjectContext(managedObjectContext!, matchingPredicate: predicate)
        if filter == nil {
            filter = ThreadFilter.insertInManagedObjectContext(managedObjectContext!)
            filter.thread = self
            filter.author = author
        }
        filter.numberOfPages = numberOfPages
    }
}

extension Thread {
    class func firstOrNewThreadWithID(threadID: String, inManagedObjectContext context: NSManagedObjectContext) -> Thread {
        if let thread = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "threadID = %@", threadID)) {
            return thread
        } else {
            let thread = insertInManagedObjectContext(context)
            thread.threadID = threadID
            return thread
        }
    }
}

@objc(ThreadFilter)
class ThreadFilter: AwfulManagedObject {
    
    @NSManaged var numberOfPages: Int32
    
    @NSManaged var author: User
    @NSManaged var thread: Thread
}
