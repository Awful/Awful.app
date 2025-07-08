# Entity Relationships

## Overview

Awful.app's Core Data model implements complex relationships that mirror the hierarchical structure of Something Awful Forums. Understanding these relationships is crucial for maintaining data integrity and implementing efficient queries during the SwiftUI migration.

## Relationship Hierarchy

```
Category
    └── Forum (parentForum/childForums)
            └── Thread
                    ├── Post
                    │   └── User (author)
                    ├── ThreadTag
                    └── User (author, bookmarkedBy)

User
    ├── Post (authored posts)
    ├── Thread (authored threads) 
    ├── PrivateMessage (sent/received)
    ├── Forum (bookmarked forums)
    └── Thread (bookmarked threads)

Announcement
    └── User (author)
```

## Core Relationships

### 1. Forum Hierarchy

Forums have a self-referencing relationship that creates the forum hierarchy:

```swift
// Forum.swift - Self-referencing forum hierarchy
@objc(Forum)
public class Forum: AwfulManagedObject {
    @NSManaged public var forumID: String
    @NSManaged public var name: String
    @NSManaged public var forumDescription: String?
    
    // Hierarchy relationships
    @NSManaged public var parentForum: Forum?
    @NSManaged public var childForums: Set<Forum>
    @NSManaged public var category: Category?
    
    // Content relationships
    @NSManaged public var threads: Set<Thread>
    
    // User relationships
    @NSManaged public var bookmarkedBy: Set<User>
    
    // Computed properties for hierarchy navigation
    var isRootForum: Bool {
        return parentForum == nil && category != nil
    }
    
    var isSubforum: Bool {
        return parentForum != nil
    }
    
    var rootForum: Forum {
        var current = self
        while let parent = current.parentForum {
            current = parent
        }
        return current
    }
    
    var allSubforums: [Forum] {
        var subforums: [Forum] = []
        
        func collectSubforums(_ forum: Forum) {
            for subforum in forum.childForums {
                subforums.append(subforum)
                collectSubforums(subforum)
            }
        }
        
        collectSubforums(self)
        return subforums
    }
}
```

### 2. Thread-Post Relationship

Threads contain ordered collections of posts:

```swift
// Thread.swift - Thread-Post relationship
@objc(Thread)
public class Thread: AwfulManagedObject {
    @NSManaged public var threadID: String
    @NSManaged public var title: String
    @NSManaged public var numberOfPosts: Int32
    
    // Forum relationship
    @NSManaged public var forum: Forum
    
    // Posts relationship (ordered)
    @NSManaged private var postsSet: Set<Post>
    
    // Computed property for ordered posts
    public var posts: [Post] {
        return postsSet.sorted { $0.postIndex < $1.postIndex }
    }
    
    // Author relationships
    @NSManaged public var author: User?
    @NSManaged public var bookmarkedBy: Set<User>
    
    // Thread metadata
    @NSManaged public var threadTag: ThreadTag?
    @NSManaged public var isBookmarked: Bool
    @NSManaged public var isLocked: Bool
    @NSManaged public var isSticky: Bool
    
    // Read tracking
    @NSManaged public var seenPosts: Int32
    @NSManaged public var totalUnreadPosts: Int32
    
    // Convenience methods
    func addPost(_ post: Post) {
        post.thread = self
        postsSet.insert(post)
    }
    
    func removePost(_ post: Post) {
        post.thread = nil
        postsSet.remove(post)
    }
    
    var unreadPosts: [Post] {
        return posts.filter { $0.postIndex > seenPosts }
    }
    
    var lastPost: Post? {
        return posts.last
    }
}
```

### 3. User Authorship and Bookmarks

Users have multiple relationship types with content:

```swift
// User.swift - Complex user relationships
@objc(User)
public class User: AwfulManagedObject {
    @NSManaged public var userID: String
    @NSManaged public var username: String
    @NSManaged public var customTitleHTML: String?
    @NSManaged public var avatarURL: String?
    
    // Profile information
    @NSManaged public var regdate: Date?
    @NSManaged public var postCount: Int32
    @NSManaged public var lastPost: Date?
    
    // Status flags
    @NSManaged public var administrator: Bool
    @NSManaged public var moderator: Bool
    
    // Authorship relationships
    @NSManaged public var posts: Set<Post>
    @NSManaged public var threads: Set<Thread>
    @NSManaged public var privateMessagesSent: Set<PrivateMessage>
    @NSManaged public var privateMessagesReceived: Set<PrivateMessage>
    @NSManaged public var announcements: Set<Announcement>
    
    // Bookmark relationships
    @NSManaged public var bookmarkedForums: Set<Forum>
    @NSManaged public var bookmarkedThreads: Set<Thread>
    
    // Computed properties
    var isCurrentUser: Bool {
        // Compare with logged-in user
        return ForumsClient.shared.loggedInUserID == userID
    }
    
    var recentPosts: [Post] {
        return posts
            .sorted { $0.postDate > $1.postDate }
            .prefix(10)
            .map { $0 }
    }
    
    var activeThreads: [Thread] {
        return threads
            .filter { !$0.isLocked }
            .sorted { $0.lastPostDate > $1.lastPostDate }
    }
}
```

### 4. Private Message Relationships

Private messages have complex sender/recipient relationships:

```swift
// PrivateMessage.swift - Message relationships
@objc(PrivateMessage)
public class PrivateMessage: AwfulManagedObject {
    @NSManaged public var messageID: String
    @NSManaged public var subject: String
    @NSManaged public var innerHTML: String
    @NSManaged public var sentDate: Date
    
    // Status flags
    @NSManaged public var seen: Bool
    @NSManaged public var forwarded: Bool
    @NSManaged public var replied: Bool
    
    // User relationships
    @NSManaged public var sender: User?
    @NSManaged public var recipient: User?
    @NSManaged public var senderUserID: String
    @NSManaged public var recipientUserID: String
    
    // Thread-like relationships for message chains
    @NSManaged public var replyTo: PrivateMessage?
    @NSManaged public var replies: Set<PrivateMessage>
    
    // Convenience methods
    var isIncoming: Bool {
        guard let currentUserID = ForumsClient.shared.loggedInUserID else { return false }
        return recipientUserID == currentUserID
    }
    
    var isOutgoing: Bool {
        guard let currentUserID = ForumsClient.shared.loggedInUserID else { return false }
        return senderUserID == currentUserID
    }
    
    var conversationMessages: [PrivateMessage] {
        var messages: [PrivateMessage] = []
        
        // Find root message
        var root = self
        while let parent = root.replyTo {
            root = parent
        }
        
        // Collect all messages in thread
        func collectReplies(_ message: PrivateMessage) {
            messages.append(message)
            for reply in message.replies.sorted(by: { $0.sentDate < $1.sentDate }) {
                collectReplies(reply)
            }
        }
        
        collectReplies(root)
        return messages
    }
}
```

## Relationship Management

### 1. Cascade Delete Rules

Proper delete rules prevent orphaned data:

```swift
// Core Data Model Configuration
extension DataStore {
    static func configureDeleteRules() {
        // Forum hierarchy: Nullify to prevent cascade deletion of entire trees
        // parentForum -> childForums: Nullify
        // childForums -> parentForum: Nullify
        
        // Content ownership: Cascade to remove orphaned content
        // Forum -> Threads: Cascade
        // Thread -> Posts: Cascade
        // User -> Posts: Nullify (preserve posts when user is deleted)
        // User -> Threads: Nullify (preserve threads when user is deleted)
        
        // Bookmarks: Nullify to preserve content when user is deleted
        // User -> bookmarkedForums: Nullify
        // User -> bookmarkedThreads: Nullify
        
        // Messages: Cascade for sender, Nullify for recipient
        // This preserves message history even if one participant is deleted
    }
}
```

### 2. Relationship Validation

Custom validation ensures relationship integrity:

```swift
// Forum.swift - Relationship validation
extension Forum {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateHierarchy()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateHierarchy()
    }
    
    private func validateHierarchy() throws {
        // Prevent circular references
        if let parent = parentForum {
            var current = parent
            var visited: Set<Forum> = [self]
            
            while let nextParent = current.parentForum {
                if visited.contains(nextParent) {
                    throw ValidationError.circularReference
                }
                visited.insert(current)
                current = nextParent
            }
        }
        
        // Validate that root forums have categories
        if parentForum == nil && category == nil {
            throw ValidationError.rootForumMissingCategory
        }
    }
}

// Thread.swift - Thread validation
extension Thread {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateRelationships()
    }
    
    private func validateRelationships() throws {
        // Thread must belong to a forum
        guard forum != nil else {
            throw ValidationError.threadMissingForum
        }
        
        // Thread must have a valid ID
        guard !threadID.isEmpty else {
            throw ValidationError.threadMissingID
        }
        
        // Validate post count consistency
        if numberOfPosts > 0 && posts.isEmpty {
            logger.warning("Thread \(threadID) has post count but no posts")
        }
    }
}
```

### 3. Batch Relationship Updates

Efficient batch operations for relationship changes:

```swift
// RelationshipManager.swift - Batch relationship operations
class RelationshipManager {
    static func batchUpdateThreadBookmarks(
        userID: String,
        threadIDs: [String],
        isBookmarked: Bool,
        in context: NSManagedObjectContext
    ) throws {
        
        context.performAndWait {
            // Get user
            guard let user = User.fetch(in: context, configurationBlock: {
                $0.predicate = NSPredicate(format: "userID == %@", userID)
            }).first else {
                throw RelationshipError.userNotFound
            }
            
            // Get threads
            let threads = Thread.fetch(in: context) {
                $0.predicate = NSPredicate(format: "threadID IN %@", threadIDs)
            }
            
            // Update relationships
            for thread in threads {
                if isBookmarked {
                    user.bookmarkedThreads.insert(thread)
                    thread.bookmarkedBy.insert(user)
                    thread.isBookmarked = true
                } else {
                    user.bookmarkedThreads.remove(thread)
                    thread.bookmarkedBy.remove(user)
                    thread.isBookmarked = false
                }
            }
            
            try context.save()
        }
    }
    
    static func rebuildForumHierarchy(
        from scrapedForums: [ScrapedForum],
        in context: NSManagedObjectContext
    ) throws {
        
        context.performAndWait {
            // Clear existing hierarchy relationships
            let allForums = Forum.fetch(in: context) { _ in }
            for forum in allForums {
                forum.parentForum = nil
                forum.childForums.removeAll()
            }
            
            // Rebuild hierarchy
            let forumsByID = Dictionary(uniqueKeysWithValues: allForums.map { ($0.forumID, $0) })
            
            for scrapedForum in scrapedForums {
                guard let forum = forumsByID[scrapedForum.forumID] else { continue }
                
                if let parentForumID = scrapedForum.parentForumID,
                   let parentForum = forumsByID[parentForumID] {
                    forum.parentForum = parentForum
                    parentForum.childForums.insert(forum)
                }
            }
            
            try context.save()
        }
    }
}
```

## Advanced Relationship Queries

### 1. Hierarchical Queries

Complex queries for forum hierarchies:

```swift
// ForumQueries.swift - Hierarchical forum queries
extension Forum {
    static func fetchRootForums(in context: NSManagedObjectContext) -> [Forum] {
        return fetch(in: context) {
            $0.predicate = NSPredicate(format: "parentForum == nil AND category != nil")
            $0.sortDescriptors = [
                NSSortDescriptor(key: "category.index", ascending: true),
                NSSortDescriptor(key: "index", ascending: true)
            ]
        }
    }
    
    static func fetchForumTree(rootForumID: String, in context: NSManagedObjectContext) -> [Forum] {
        guard let rootForum = fetch(in: context, configurationBlock: {
            $0.predicate = NSPredicate(format: "forumID == %@", rootForumID)
        }).first else {
            return []
        }
        
        var result: [Forum] = [rootForum]
        
        func addSubforums(_ forum: Forum, depth: Int = 0) {
            let subforums = forum.childForums.sorted { 
                ($0.index ?? 0) < ($1.index ?? 0) 
            }
            
            for subforum in subforums {
                result.append(subforum)
                addSubforums(subforum, depth: depth + 1)
            }
        }
        
        addSubforums(rootForum)
        return result
    }
    
    static func fetchForumsContaining(
        searchText: String,
        in context: NSManagedObjectContext
    ) -> [Forum] {
        return fetch(in: context) {
            $0.predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR forumDescription CONTAINS[cd] %@", 
                                     searchText, searchText)
            $0.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        }
    }
}
```

### 2. User Activity Queries

Complex queries for user relationships:

```swift
// UserQueries.swift - User activity queries
extension User {
    static func fetchMostActivePosters(
        in forum: Forum,
        context: NSManagedObjectContext,
        limit: Int = 10
    ) -> [User] {
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        // Subquery to count posts in specific forum
        let subquery = NSPredicate(format: "SUBQUERY(posts, $post, $post.thread.forum == %@).@count > 0", forum)
        request.predicate = subquery
        
        // Sort by post count in forum
        let expression = NSExpression(forKeyPath: "posts.@count")
        let sortDescriptor = NSSortDescriptor(key: "posts.@count", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            logger.error("Failed to fetch active posters: \(error)")
            return []
        }
    }
    
    func threadsInForum(_ forum: Forum) -> [Thread] {
        return threads.filter { $0.forum == forum }
            .sorted { $0.lastPostDate > $1.lastPostDate }
    }
    
    func postsInThread(_ thread: Thread) -> [Post] {
        return posts.filter { $0.thread == thread }
            .sorted { $0.postIndex < $1.postIndex }
    }
}
```

### 3. Cross-Relationship Queries

Queries spanning multiple relationships:

```swift
// CrossRelationshipQueries.swift - Complex relationship queries
extension NSManagedObjectContext {
    func fetchThreadsWithUnreadPosts(for user: User) -> [Thread] {
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        
        // Threads bookmarked by user with unread posts
        request.predicate = NSPredicate(format: 
            "ANY bookmarkedBy == %@ AND totalUnreadPosts > 0", user)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        
        do {
            return try fetch(request)
        } catch {
            logger.error("Failed to fetch unread threads: \(error)")
            return []
        }
    }
    
    func fetchPopularThreads(
        in forum: Forum,
        minimumPosts: Int = 10,
        timeframe: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    ) -> [Thread] {
        let startDate = Date().addingTimeInterval(-timeframe)
        
        let request: NSFetchRequest<Thread> = Thread.fetchRequest()
        request.predicate = NSPredicate(format: 
            "forum == %@ AND numberOfPosts >= %d AND lastPostDate >= %@",
            forum, minimumPosts, startDate as NSDate)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "numberOfPosts", ascending: false),
            NSSortDescriptor(key: "lastPostDate", ascending: false)
        ]
        
        do {
            return try fetch(request)
        } catch {
            logger.error("Failed to fetch popular threads: \(error)")
            return []
        }
    }
}
```

## Performance Optimization

### 1. Relationship Prefetching

Optimize queries with relationship prefetching:

```swift
// OptimizedQueries.swift - Relationship prefetching
extension Thread {
    static func fetchWithFullData(
        in forum: Forum,
        context: NSManagedObjectContext
    ) -> [Thread] {
        return fetch(in: context) {
            $0.predicate = NSPredicate(format: "forum == %@", forum)
            $0.sortDescriptors = [
                NSSortDescriptor(key: "isSticky", ascending: false),
                NSSortDescriptor(key: "lastPostDate", ascending: false)
            ]
            
            // Pre-fetch related objects to avoid N+1 queries
            $0.relationshipKeyPathsForPrefetching = [
                "author",
                "threadTag", 
                "posts.author",
                "bookmarkedBy"
            ]
            
            // Limit memory usage
            $0.fetchBatchSize = 20
            $0.returnsObjectsAsFaults = false
        }
    }
}
```

### 2. Denormalized Relationship Data

Store computed relationship data for performance:

```swift
// Thread.swift - Denormalized data
extension Thread {
    // Denormalized author data for quick access
    @NSManaged public var authorUserID: String?
    @NSManaged public var lastPostAuthorName: String?
    @NSManaged public var lastPostDate: Date?
    
    // Update denormalized data when relationships change
    func updateDenormalizedData() {
        authorUserID = author?.userID
        
        if let lastPost = posts.last {
            lastPostAuthorName = lastPost.author?.username
            lastPostDate = lastPost.postDate
        }
    }
}
```

## SwiftUI Integration

### 1. Relationship Observation

SwiftUI views observing relationship changes:

```swift
// RelationshipObserverView.swift - SwiftUI relationship observation
struct ThreadDetailView: View {
    @ObservedObject var thread: Thread
    
    // Observe posts relationship
    @FetchRequest private var posts: FetchedResults<Post>
    
    init(thread: Thread) {
        self.thread = thread
        
        // Set up posts fetch request
        _posts = FetchRequest(
            entity: Post.entity(),
            sortDescriptors: [NSSortDescriptor(key: "postIndex", ascending: true)],
            predicate: NSPredicate(format: "thread == %@", thread)
        )
    }
    
    var body: some View {
        VStack {
            // Thread info
            Text(thread.title)
                .font(.title)
            
            // Author info from relationship
            if let author = thread.author {
                HStack {
                    AsyncImage(url: URL(string: author.avatarURL ?? ""))
                        .frame(width: 32, height: 32)
                    Text(author.username)
                        .font(.caption)
                }
            }
            
            // Posts list
            List(posts) { post in
                PostRowView(post: post)
            }
        }
    }
}
```

### 2. Relationship Management in SwiftUI

```swift
// BookmarkManager.swift - SwiftUI bookmark management
@MainActor
class BookmarkManager: ObservableObject {
    @Published var bookmarkedThreads: Set<Thread> = []
    
    private let context: NSManagedObjectContext
    private let user: User
    
    init(context: NSManagedObjectContext, user: User) {
        self.context = context
        self.user = user
        self.bookmarkedThreads = user.bookmarkedThreads
    }
    
    func toggleBookmark(for thread: Thread) {
        if bookmarkedThreads.contains(thread) {
            removeBookmark(for: thread)
        } else {
            addBookmark(for: thread)
        }
    }
    
    private func addBookmark(for thread: Thread) {
        user.bookmarkedThreads.insert(thread)
        thread.bookmarkedBy.insert(user)
        thread.isBookmarked = true
        
        bookmarkedThreads.insert(thread)
        
        saveContext()
    }
    
    private func removeBookmark(for thread: Thread) {
        user.bookmarkedThreads.remove(thread)
        thread.bookmarkedBy.remove(user)
        thread.isBookmarked = false
        
        bookmarkedThreads.remove(thread)
        
        saveContext()
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save bookmark changes: \(error)")
        }
    }
}
```

## Testing Relationships

### 1. Relationship Integrity Tests

```swift
// RelationshipTests.swift - Relationship testing
class RelationshipTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    
    func testForumHierarchy() {
        // Given: Forum hierarchy
        let category = Category.insert(into: testContext)
        let rootForum = Forum.insert(into: testContext)
        let subforum = Forum.insert(into: testContext)
        
        rootForum.category = category
        subforum.parentForum = rootForum
        
        // When: Accessing hierarchy
        XCTAssertEqual(subforum.rootForum, rootForum)
        XCTAssertTrue(rootForum.isRootForum)
        XCTAssertTrue(subforum.isSubforum)
        XCTAssertTrue(rootForum.allSubforums.contains(subforum))
    }
    
    func testThreadPostRelationship() {
        // Given: Thread with posts
        let thread = Thread.insert(into: testContext)
        
        let post1 = Post.insert(into: testContext)
        post1.postIndex = 1
        
        let post2 = Post.insert(into: testContext)
        post2.postIndex = 2
        
        // When: Adding posts to thread
        thread.addPost(post1)
        thread.addPost(post2)
        
        // Then: Posts are ordered correctly
        XCTAssertEqual(thread.posts.count, 2)
        XCTAssertEqual(thread.posts.first?.postIndex, 1)
        XCTAssertEqual(thread.posts.last?.postIndex, 2)
        XCTAssertEqual(thread.lastPost, post2)
    }
    
    func testCascadeDelete() {
        // Given: Forum with threads and posts
        let forum = Forum.insert(into: testContext)
        let thread = Thread.insert(into: testContext)
        let post = Post.insert(into: testContext)
        
        thread.forum = forum
        post.thread = thread
        
        try! testContext.save()
        
        // When: Deleting forum
        testContext.delete(forum)
        try! testContext.save()
        
        // Then: Thread and post are also deleted (cascade)
        XCTAssertTrue(thread.isDeleted)
        XCTAssertTrue(post.isDeleted)
    }
}
```

Understanding and properly managing these entity relationships is crucial for maintaining data integrity and implementing efficient queries in the SwiftUI migration while preserving all existing functionality.