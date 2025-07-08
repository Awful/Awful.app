# Offline Support

## Overview

Awful.app's offline support system enables users to read cached forum content, compose posts, and maintain functionality when network connectivity is unavailable. This system has been essential for mobile forum usage and provides a robust foundation for modern offline-first app design.

## Offline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Offline Support System                       │
├─────────────────────────────────────────────────────────────────┤
│  Content Caching                                               │
│  ├─ Forum Hierarchy Cache                                      │
│  ├─ Thread Content Cache                                       │
│  ├─ Post Content Cache                                         │
│  └─ Media Asset Cache                                          │
├─────────────────────────────────────────────────────────────────┤
│  Offline Operations                                             │
│  ├─ Draft Management                                           │
│  ├─ Read Status Tracking                                       │
│  ├─ Bookmark Management                                        │
│  └─ User Preference Storage                                    │
├─────────────────────────────────────────────────────────────────┤
│  Synchronization                                                │
│  ├─ Delta Sync on Reconnection                                │
│  ├─ Conflict Resolution                                        │
│  ├─ Queue Management                                           │
│  └─ Background Sync                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Content Caching Strategy

### 1. Hierarchical Content Caching

Cache forum content in a hierarchical manner for efficient offline access:

```swift
// OfflineCacheManager.swift - Hierarchical content caching
class OfflineCacheManager {
    private let context: NSManagedObjectContext
    private let networkMonitor: NetworkMonitor
    
    enum CacheLevel: Int, CaseIterable {
        case essential = 1      // Forum hierarchy, bookmarked threads
        case important = 2      // Recent threads, user posts
        case extended = 3       // Full thread content
        case media = 4          // Images, avatars
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.networkMonitor = NetworkMonitor.shared
        setupOfflineCaching()
    }
    
    private func setupOfflineCaching() {
        // Monitor network changes
        networkMonitor.onNetworkStatusChange = { [weak self] isConnected in
            if isConnected {
                self?.performIncrementalSync()
            } else {
                self?.enableOfflineMode()
            }
        }
        
        // Cache management
        schedulePeriodicCacheManagement()
    }
    
    func cacheEssentialContent() {
        context.perform {
            // Cache forum hierarchy
            self.cacheForumHierarchy()
            
            // Cache bookmarked threads
            self.cacheBookmarkedThreads()
            
            // Cache user's recent activity
            self.cacheUserActivity()
            
            // Mark content as cached
            self.updateCacheMetadata(level: .essential)
        }
    }
    
    private func cacheForumHierarchy() {
        let forums = Forum.fetch(in: context) { request in
            request.sortDescriptors = [
                NSSortDescriptor(key: "category.index", ascending: true),
                NSSortDescriptor(key: "index", ascending: true)
            ]
            // Pre-fetch relationships for offline access
            request.relationshipKeyPathsForPrefetching = [
                "category",
                "parentForum",
                "childForums"
            ]
        }
        
        // Ensure all forum data is faulted in
        for forum in forums {
            _ = forum.name
            _ = forum.forumDescription
            _ = forum.category?.name
        }
        
        logger.info("Cached \(forums.count) forums for offline access")
    }
    
    private func cacheBookmarkedThreads() {
        guard let currentUser = getCurrentUser() else { return }
        
        let bookmarkedThreads = Array(currentUser.bookmarkedThreads)
        
        for thread in bookmarkedThreads {
            cacheThreadContent(thread, level: .important)
        }
        
        logger.info("Cached \(bookmarkedThreads.count) bookmarked threads")
    }
    
    private func cacheThreadContent(_ thread: Thread, level: CacheLevel) {
        // Cache thread metadata
        _ = thread.title
        _ = thread.author?.username
        _ = thread.threadTag?.name
        
        // Cache posts based on level
        let postsToCache: [Post]
        switch level {
        case .essential:
            // Cache first and last few posts
            postsToCache = Array(thread.posts.prefix(5)) + Array(thread.posts.suffix(5))
        case .important:
            // Cache first page of posts
            postsToCache = Array(thread.posts.prefix(40))
        case .extended:
            // Cache all posts
            postsToCache = thread.posts
        case .media:
            // Just metadata, media cached separately
            postsToCache = []
        }
        
        for post in postsToCache {
            cachePostContent(post)
        }
        
        // Mark thread as cached
        thread.setValue(Date(), forKey: "lastCachedDate")
        thread.setValue(level.rawValue, forKey: "cacheLevel")
    }
    
    private func cachePostContent(_ post: Post) {
        // Ensure post content is loaded
        _ = post.innerHTML
        _ = post.text
        _ = post.author?.username
        _ = post.author?.avatarURL
        
        // Cache embedded media references
        cachePostMedia(post)
    }
    
    private func cachePostMedia(_ post: Post) {
        guard let html = post.innerHTML else { return }
        
        // Extract image URLs from post content
        let imageURLs = extractImageURLs(from: html)
        
        for imageURL in imageURLs {
            MediaCacheManager.shared.cacheImage(url: imageURL, priority: .normal)
        }
        
        // Cache author avatar
        if let avatarURL = post.author?.avatarURL {
            MediaCacheManager.shared.cacheImage(url: avatarURL, priority: .low)
        }
    }
}
```

### 2. Intelligent Cache Prioritization

Prioritize cache content based on user behavior:

```swift
// CachePrioritizer.swift - Intelligent cache prioritization
class CachePrioritizer {
    private let context: NSManagedObjectContext
    private let analytics: AnalyticsManager
    
    struct CachePriority {
        let item: CacheableItem
        let score: Double
        let reason: String
    }
    
    enum CacheableItem {
        case thread(Thread)
        case forum(Forum)
        case post(Post)
    }
    
    init(context: NSManagedObjectContext, analytics: AnalyticsManager) {
        self.context = context
        self.analytics = analytics
    }
    
    func prioritizeContentForCaching(availableSpace: Int64) -> [CachePriority] {
        var priorities: [CachePriority] = []
        
        // Analyze user behavior patterns
        let userActivity = analytics.getUserActivityPatterns()
        
        // Prioritize bookmarked threads
        priorities.append(contentsOf: prioritizeBookmarkedThreads(activity: userActivity))
        
        // Prioritize frequently visited forums
        priorities.append(contentsOf: prioritizeFrequentForums(activity: userActivity))
        
        // Prioritize recent threads
        priorities.append(contentsOf: prioritizeRecentThreads(activity: userActivity))
        
        // Sort by priority score and fit within available space
        priorities.sort { $0.score > $1.score }
        
        return filterByAvailableSpace(priorities, availableSpace: availableSpace)
    }
    
    private func prioritizeBookmarkedThreads(activity: UserActivityPattern) -> [CachePriority] {
        guard let currentUser = getCurrentUser() else { return [] }
        
        return currentUser.bookmarkedThreads.map { thread in
            var score = 100.0 // Base score for bookmarked content
            
            // Boost score for recently viewed threads
            if let lastViewed = activity.threadLastViewed[thread.threadID] {
                let daysSinceViewed = Date().timeIntervalSince(lastViewed) / (24 * 60 * 60)
                score += max(0, 50.0 - daysSinceViewed) // More recent = higher score
            }
            
            // Boost score for threads with unread posts
            if thread.totalUnreadPosts > 0 {
                score += 25.0
            }
            
            // Boost score for active threads
            if let lastPost = thread.lastPostDate {
                let daysSincePost = Date().timeIntervalSince(lastPost) / (24 * 60 * 60)
                score += max(0, 20.0 - daysSincePost)
            }
            
            return CachePriority(
                item: .thread(thread),
                score: score,
                reason: "Bookmarked thread with \(thread.totalUnreadPosts) unread posts"
            )
        }
    }
    
    private func prioritizeFrequentForums(activity: UserActivityPattern) -> [CachePriority] {
        return activity.forumVisitCount.map { (forumID, visitCount) in
            guard let forum = Forum.fetch(in: context, configurationBlock: {
                $0.predicate = NSPredicate(format: "forumID == %@", forumID)
            }).first else {
                return nil
            }
            
            let score = Double(visitCount) * 2.0 // 2 points per visit
            
            return CachePriority(
                item: .forum(forum),
                score: score,
                reason: "Frequently visited forum (\(visitCount) visits)"
            )
        }.compactMap { $0 }
    }
    
    private func prioritizeRecentThreads(activity: UserActivityPattern) -> [CachePriority] {
        let recentThreads = Thread.fetch(in: context) {
            $0.predicate = NSPredicate(format: "lastPostDate >= %@", 
                                     Date().addingTimeInterval(-7 * 24 * 60 * 60) as NSDate)
            $0.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            $0.fetchLimit = 50
        }
        
        return recentThreads.map { thread in
            var score = 10.0 // Base score for recent content
            
            // Boost score for threads in frequently visited forums
            if let forumVisits = activity.forumVisitCount[thread.forum.forumID] {
                score += Double(forumVisits) * 0.5
            }
            
            return CachePriority(
                item: .thread(thread),
                score: score,
                reason: "Recent thread in active forum"
            )
        }
    }
    
    private func filterByAvailableSpace(_ priorities: [CachePriority], availableSpace: Int64) -> [CachePriority] {
        var result: [CachePriority] = []
        var usedSpace: Int64 = 0
        
        for priority in priorities {
            let estimatedSize = estimateItemSize(priority.item)
            
            if usedSpace + estimatedSize <= availableSpace {
                result.append(priority)
                usedSpace += estimatedSize
            } else {
                break // Can't fit more items
            }
        }
        
        logger.info("Selected \(result.count) items for caching, using \(usedSpace / 1024 / 1024)MB")
        return result
    }
    
    private func estimateItemSize(_ item: CacheableItem) -> Int64 {
        switch item {
        case .thread(let thread):
            // Estimate based on post count and average post size
            return Int64(thread.numberOfPosts) * 2048 // 2KB per post average
        case .forum(let forum):
            // Forum metadata is relatively small
            return 1024 // 1KB for forum info
        case .post(let post):
            // Estimate based on content length
            return Int64((post.innerHTML?.count ?? 0) + (post.text?.count ?? 0))
        }
    }
}
```

### 3. Media Asset Caching

Comprehensive media caching for offline access:

```swift
// MediaCacheManager.swift - Media asset caching
class MediaCacheManager {
    static let shared = MediaCacheManager()
    
    private let cacheDirectory: URL
    private let urlSession: URLSession
    private let cache: NSCache<NSString, CachedMedia>
    private let downloadQueue = DispatchQueue(label: "media-cache", qos: .background)
    
    enum CachePriority {
        case high, normal, low
    }
    
    struct CachedMedia {
        let data: Data
        let mimeType: String
        let cachedDate: Date
        let url: URL
    }
    
    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("MediaCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, 
                                               withIntermediateDirectories: true)
        
        // Configure URL session for media downloads
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, // 50MB memory
                                 diskCapacity: 200 * 1024 * 1024,     // 200MB disk
                                 directoryURL: cacheDirectory.appendingPathComponent("URLCache"))
        
        urlSession = URLSession(configuration: config)
        
        // Configure in-memory cache
        cache = NSCache<NSString, CachedMedia>()
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        setupCacheManagement()
    }
    
    func cacheImage(url: String, priority: CachePriority = .normal) {
        guard let imageURL = URL(string: url) else { return }
        
        let cacheKey = url as NSString
        
        // Check if already cached
        if cache.object(forKey: cacheKey) != nil {
            return
        }
        
        // Check disk cache
        if let cachedData = loadFromDiskCache(url: imageURL) {
            let cachedMedia = CachedMedia(
                data: cachedData,
                mimeType: "image/jpeg", // Default, could be improved
                cachedDate: Date(),
                url: imageURL
            )
            cache.setObject(cachedMedia, forKey: cacheKey, cost: cachedData.count)
            return
        }
        
        // Download and cache
        downloadAndCacheMedia(url: imageURL, priority: priority)
    }
    
    private func downloadAndCacheMedia(url: URL, priority: CachePriority) {
        downloadQueue.async {
            let task = self.urlSession.dataTask(with: url) { data, response, error in
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    logger.error("Failed to download media from \(url): \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let mimeType = httpResponse.mimeType ?? "application/octet-stream"
                
                let cachedMedia = CachedMedia(
                    data: data,
                    mimeType: mimeType,
                    cachedDate: Date(),
                    url: url
                )
                
                // Store in memory cache
                let cacheKey = url.absoluteString as NSString
                self.cache.setObject(cachedMedia, forKey: cacheKey, cost: data.count)
                
                // Store in disk cache
                self.saveToDiskCache(media: cachedMedia)
                
                logger.debug("Cached media: \(url) (\(data.count) bytes)")
            }
            
            // Set priority
            switch priority {
            case .high:
                task.priority = URLSessionTask.highPriority
            case .normal:
                task.priority = URLSessionTask.defaultPriority
            case .low:
                task.priority = URLSessionTask.lowPriority
            }
            
            task.resume()
        }
    }
    
    func getCachedMedia(url: String) -> CachedMedia? {
        let cacheKey = url as NSString
        
        // Check memory cache first
        if let cachedMedia = cache.object(forKey: cacheKey) {
            return cachedMedia
        }
        
        // Check disk cache
        guard let imageURL = URL(string: url),
              let data = loadFromDiskCache(url: imageURL) else {
            return nil
        }
        
        let cachedMedia = CachedMedia(
            data: data,
            mimeType: "image/jpeg", // Could be improved with proper detection
            cachedDate: Date(),
            url: imageURL
        )
        
        // Store back in memory cache
        cache.setObject(cachedMedia, forKey: cacheKey, cost: data.count)
        
        return cachedMedia
    }
    
    private func saveToDiskCache(media: CachedMedia) {
        let fileName = media.url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            try media.data.write(to: fileURL)
        } catch {
            logger.error("Failed to save media to disk cache: \(error)")
        }
    }
    
    private func loadFromDiskCache(url: URL) -> Data? {
        let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        return try? Data(contentsOf: fileURL)
    }
    
    private func setupCacheManagement() {
        // Clear old cache entries periodically
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            self.cleanupOldCacheEntries()
        }
        
        // Handle memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.cache.removeAllObjects()
        }
    }
    
    private func cleanupOldCacheEntries() {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days old
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                          includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            logger.error("Failed to cleanup cache: \(error)")
        }
    }
}
```

## Offline Operations

### 1. Draft Management

Comprehensive draft management for offline composition:

```swift
// DraftManager.swift - Offline draft management
class DraftManager {
    private let context: NSManagedObjectContext
    private let fileManager = FileManager.default
    private let draftsDirectory: URL
    
    enum DraftType {
        case newThread(forumID: String)
        case reply(threadID: String)
        case edit(postID: String)
        case privateMessage(recipientID: String?)
    }
    
    struct Draft {
        let id: UUID
        let type: DraftType
        let content: String
        let subject: String?
        let createdDate: Date
        let modifiedDate: Date
        let attachments: [DraftAttachment]
    }
    
    struct DraftAttachment {
        let id: UUID
        let filename: String
        let data: Data
        let mimeType: String
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        draftsDirectory = documentsDir.appendingPathComponent("Drafts")
        
        // Create drafts directory
        try? fileManager.createDirectory(at: draftsDirectory, withIntermediateDirectories: true)
        
        setupDraftSyncronization()
    }
    
    func saveDraft(type: DraftType, content: String, subject: String? = nil, attachments: [DraftAttachment] = []) -> UUID {
        let draftID = UUID()
        
        let draft = Draft(
            id: draftID,
            type: type,
            content: content,
            subject: subject,
            createdDate: Date(),
            modifiedDate: Date(),
            attachments: attachments
        )
        
        saveDraftToDisk(draft)
        
        // Save draft metadata to Core Data for sync
        saveDraftMetadata(draft)
        
        logger.info("Saved draft: \(draftID)")
        return draftID
    }
    
    func updateDraft(id: UUID, content: String, subject: String? = nil) {
        guard var draft = loadDraft(id: id) else { return }
        
        draft = Draft(
            id: draft.id,
            type: draft.type,
            content: content,
            subject: subject ?? draft.subject,
            createdDate: draft.createdDate,
            modifiedDate: Date(),
            attachments: draft.attachments
        )
        
        saveDraftToDisk(draft)
        updateDraftMetadata(draft)
        
        logger.info("Updated draft: \(id)")
    }
    
    func loadDraft(id: UUID) -> Draft? {
        let draftURL = draftsDirectory.appendingPathComponent("\(id.uuidString).draft")
        
        guard let data = try? Data(contentsOf: draftURL),
              let draft = try? JSONDecoder().decode(Draft.self, from: data) else {
            return nil
        }
        
        return draft
    }
    
    func getAllDrafts() -> [Draft] {
        guard let files = try? fileManager.contentsOfDirectory(at: draftsDirectory, 
                                                             includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { fileURL in
            guard fileURL.pathExtension == "draft",
                  let data = try? Data(contentsOf: fileURL),
                  let draft = try? JSONDecoder().decode(Draft.self, from: data) else {
                return nil
            }
            return draft
        }.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    func deleteDraft(id: UUID) {
        let draftURL = draftsDirectory.appendingPathComponent("\(id.uuidString).draft")
        try? fileManager.removeItem(at: draftURL)
        
        // Remove metadata from Core Data
        deleteDraftMetadata(id: id)
        
        logger.info("Deleted draft: \(id)")
    }
    
    private func saveDraftToDisk(_ draft: Draft) {
        let draftURL = draftsDirectory.appendingPathComponent("\(draft.id.uuidString).draft")
        
        do {
            let data = try JSONEncoder().encode(draft)
            try data.write(to: draftURL)
        } catch {
            logger.error("Failed to save draft to disk: \(error)")
        }
    }
    
    private func saveDraftMetadata(_ draft: Draft) {
        context.perform {
            let draftEntity = DraftEntity.insert(into: self.context)
            draftEntity.draftID = draft.id.uuidString
            draftEntity.createdDate = draft.createdDate
            draftEntity.modifiedDate = draft.modifiedDate
            draftEntity.needsSync = true
            
            // Store type-specific metadata
            switch draft.type {
            case .newThread(let forumID):
                draftEntity.type = "newThread"
                draftEntity.forumID = forumID
            case .reply(let threadID):
                draftEntity.type = "reply"
                draftEntity.threadID = threadID
            case .edit(let postID):
                draftEntity.type = "edit"
                draftEntity.postID = postID
            case .privateMessage(let recipientID):
                draftEntity.type = "privateMessage"
                draftEntity.recipientID = recipientID
            }
            
            try? self.context.save()
        }
    }
    
    private func updateDraftMetadata(_ draft: Draft) {
        context.perform {
            let fetchRequest: NSFetchRequest<DraftEntity> = DraftEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "draftID == %@", draft.id.uuidString)
            
            if let draftEntity = try? self.context.fetch(fetchRequest).first {
                draftEntity.modifiedDate = draft.modifiedDate
                draftEntity.needsSync = true
                try? self.context.save()
            }
        }
    }
    
    private func deleteDraftMetadata(id: UUID) {
        context.perform {
            let fetchRequest: NSFetchRequest<DraftEntity> = DraftEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "draftID == %@", id.uuidString)
            
            if let draftEntity = try? self.context.fetch(fetchRequest).first {
                self.context.delete(draftEntity)
                try? self.context.save()
            }
        }
    }
    
    private func setupDraftSyncronization() {
        // Sync drafts when network becomes available
        NetworkMonitor.shared.onNetworkStatusChange = { [weak self] isConnected in
            if isConnected {
                self?.syncDraftsWithServer()
            }
        }
    }
    
    private func syncDraftsWithServer() {
        // Implement draft synchronization logic
        logger.info("Syncing drafts with server...")
    }
}
```

### 2. Read Status Management

Track read status for offline threads:

```swift
// ReadStatusManager.swift - Offline read status tracking
class ReadStatusManager {
    private let context: NSManagedObjectContext
    private var pendingUpdates: [String: ReadUpdate] = [:]
    
    struct ReadUpdate {
        let threadID: String
        let seenPosts: Int32
        let timestamp: Date
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupSynchronization()
    }
    
    func markThreadAsRead(_ thread: Thread, upToPost postIndex: Int32? = nil) {
        let finalPostIndex = postIndex ?? thread.numberOfPosts
        
        // Update local state immediately
        context.perform {
            thread.seenPosts = finalPostIndex
            thread.totalUnreadPosts = max(0, thread.numberOfPosts - finalPostIndex)
            
            try? self.context.save()
        }
        
        // Queue update for server sync
        let update = ReadUpdate(
            threadID: thread.threadID,
            seenPosts: finalPostIndex,
            timestamp: Date()
        )
        
        pendingUpdates[thread.threadID] = update
        
        // Attempt immediate sync if online
        if NetworkMonitor.shared.isConnected {
            syncReadStatus(for: thread.threadID)
        }
        
        logger.debug("Marked thread \(thread.threadID) as read up to post \(finalPostIndex)")
    }
    
    func markPostAsRead(_ post: Post) {
        guard let thread = post.thread else { return }
        
        let currentSeenPosts = thread.seenPosts
        let postIndex = post.postIndex
        
        // Only update if this post is beyond current read position
        if postIndex > currentSeenPosts {
            markThreadAsRead(thread, upToPost: postIndex)
        }
    }
    
    func getUnreadCount(for forum: Forum) -> Int32 {
        let threads = forum.threads
        return threads.reduce(0) { total, thread in
            total + thread.totalUnreadPosts
        }
    }
    
    func getUnreadThreads(for forum: Forum) -> [Thread] {
        return forum.threads.filter { $0.totalUnreadPosts > 0 }
            .sorted { $0.lastPostDate > $1.lastPostDate }
    }
    
    private func syncReadStatus(for threadID: String) {
        guard let update = pendingUpdates[threadID] else { return }
        
        ForumsClient.shared.markThreadAsRead(threadID: threadID, upToPost: update.seenPosts) { result in
            switch result {
            case .success:
                // Remove from pending updates
                self.pendingUpdates.removeValue(forKey: threadID)
                logger.debug("Synced read status for thread \(threadID)")
                
            case .failure(let error):
                logger.error("Failed to sync read status for thread \(threadID): \(error)")
                // Keep in pending updates for retry
            }
        }
    }
    
    private func setupSynchronization() {
        // Sync pending updates when network becomes available
        NetworkMonitor.shared.onNetworkStatusChange = { [weak self] isConnected in
            if isConnected {
                self?.syncAllPendingUpdates()
            }
        }
        
        // Periodic sync of pending updates
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            if NetworkMonitor.shared.isConnected {
                self.syncAllPendingUpdates()
            }
        }
    }
    
    private func syncAllPendingUpdates() {
        for threadID in pendingUpdates.keys {
            syncReadStatus(for: threadID)
        }
    }
}
```

### 3. Offline Bookmark Management

Manage bookmarks when offline:

```swift
// OfflineBookmarkManager.swift - Offline bookmark management
class OfflineBookmarkManager {
    private let context: NSManagedObjectContext
    private var pendingBookmarkChanges: [BookmarkChange] = []
    
    enum BookmarkChange {
        case add(threadID: String)
        case remove(threadID: String)
        
        var threadID: String {
            switch self {
            case .add(let id), .remove(let id):
                return id
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupSynchronization()
        loadPendingChanges()
    }
    
    func addBookmark(_ thread: Thread) {
        // Update local state immediately
        context.perform {
            thread.isBookmarked = true
            
            if let currentUser = self.getCurrentUser() {
                currentUser.bookmarkedThreads.insert(thread)
                thread.bookmarkedBy.insert(currentUser)
            }
            
            try? self.context.save()
        }
        
        // Queue change for server sync
        let change = BookmarkChange.add(threadID: thread.threadID)
        addPendingChange(change)
        
        // Attempt immediate sync if online
        if NetworkMonitor.shared.isConnected {
            syncBookmarkChange(change)
        }
        
        logger.debug("Added bookmark for thread \(thread.threadID)")
    }
    
    func removeBookmark(_ thread: Thread) {
        // Update local state immediately
        context.perform {
            thread.isBookmarked = false
            
            if let currentUser = self.getCurrentUser() {
                currentUser.bookmarkedThreads.remove(thread)
                thread.bookmarkedBy.remove(currentUser)
            }
            
            try? self.context.save()
        }
        
        // Queue change for server sync
        let change = BookmarkChange.remove(threadID: thread.threadID)
        addPendingChange(change)
        
        // Attempt immediate sync if online
        if NetworkMonitor.shared.isConnected {
            syncBookmarkChange(change)
        }
        
        logger.debug("Removed bookmark for thread \(thread.threadID)")
    }
    
    func getBookmarkedThreads() -> [Thread] {
        guard let currentUser = getCurrentUser() else { return [] }
        
        return Array(currentUser.bookmarkedThreads)
            .sorted { $0.lastPostDate > $1.lastPostDate }
    }
    
    private func addPendingChange(_ change: BookmarkChange) {
        // Remove any existing change for this thread
        pendingBookmarkChanges.removeAll { $0.threadID == change.threadID }
        
        // Add new change
        pendingBookmarkChanges.append(change)
        
        // Persist pending changes
        savePendingChanges()
    }
    
    private func syncBookmarkChange(_ change: BookmarkChange) {
        switch change {
        case .add(let threadID):
            ForumsClient.shared.addBookmark(threadID: threadID) { result in
                self.handleSyncResult(result, for: change)
            }
            
        case .remove(let threadID):
            ForumsClient.shared.removeBookmark(threadID: threadID) { result in
                self.handleSyncResult(result, for: change)
            }
        }
    }
    
    private func handleSyncResult(_ result: Result<Void, Error>, for change: BookmarkChange) {
        switch result {
        case .success:
            // Remove from pending changes
            pendingBookmarkChanges.removeAll { $0.threadID == change.threadID }
            savePendingChanges()
            logger.debug("Synced bookmark change for thread \(change.threadID)")
            
        case .failure(let error):
            logger.error("Failed to sync bookmark change for thread \(change.threadID): \(error)")
            // Keep in pending changes for retry
        }
    }
    
    private func setupSynchronization() {
        // Sync pending changes when network becomes available
        NetworkMonitor.shared.onNetworkStatusChange = { [weak self] isConnected in
            if isConnected {
                self?.syncAllPendingChanges()
            }
        }
    }
    
    private func syncAllPendingChanges() {
        for change in pendingBookmarkChanges {
            syncBookmarkChange(change)
        }
    }
    
    private func savePendingChanges() {
        let data = try? JSONEncoder().encode(pendingBookmarkChanges)
        UserDefaults.standard.set(data, forKey: "PendingBookmarkChanges")
    }
    
    private func loadPendingChanges() {
        guard let data = UserDefaults.standard.data(forKey: "PendingBookmarkChanges"),
              let changes = try? JSONDecoder().decode([BookmarkChange].self, from: data) else {
            return
        }
        
        pendingBookmarkChanges = changes
    }
}
```

## Synchronization

### 1. Delta Synchronization

Efficient delta sync when reconnecting:

```swift
// DeltaSyncManager.swift - Efficient delta synchronization
class DeltaSyncManager {
    private let context: NSManagedObjectContext
    private let lastSyncManager: LastSyncManager
    
    struct SyncResult {
        let threadsUpdated: Int
        let postsUpdated: Int
        let bookmarksUpdated: Int
        let duration: TimeInterval
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.lastSyncManager = LastSyncManager()
    }
    
    func performDeltaSync() async throws -> SyncResult {
        let startTime = Date()
        
        // Get last sync timestamps
        let lastSync = lastSyncManager.getLastSyncDate()
        logger.info("Starting delta sync from \(lastSync)")
        
        // Sync in priority order
        let threadUpdates = try await syncThreadUpdates(since: lastSync)
        let postUpdates = try await syncPostUpdates(since: lastSync)
        let bookmarkUpdates = try await syncBookmarkUpdates(since: lastSync)
        
        // Update last sync timestamp
        lastSyncManager.updateLastSyncDate(Date())
        
        let duration = Date().timeIntervalSince(startTime)
        
        let result = SyncResult(
            threadsUpdated: threadUpdates,
            postsUpdated: postUpdates,
            bookmarksUpdated: bookmarkUpdates,
            duration: duration
        )
        
        logger.info("Delta sync completed: \(threadUpdates) threads, \(postUpdates) posts, \(bookmarkUpdates) bookmarks in \(String(format: "%.2f", duration))s")
        
        return result
    }
    
    private func syncThreadUpdates(since lastSync: Date) async throws -> Int {
        // Get threads that need updating
        let threadsToUpdate = getThreadsNeedingUpdate(since: lastSync)
        
        guard !threadsToUpdate.isEmpty else { return 0 }
        
        // Batch update threads
        let batchSize = 10
        var updatedCount = 0
        
        for batch in threadsToUpdate.chunked(into: batchSize) {
            let threadIDs = batch.map { $0.threadID }
            
            do {
                let updatedThreads = try await ForumsClient.shared.getThreadUpdates(threadIDs: threadIDs, since: lastSync)
                
                try await updateThreadsInBackground(updatedThreads)
                updatedCount += updatedThreads.count
                
            } catch {
                logger.error("Failed to sync thread batch: \(error)")
                throw error
            }
        }
        
        return updatedCount
    }
    
    private func syncPostUpdates(since lastSync: Date) async throws -> Int {
        // Get threads with potential new posts
        let activeThreads = getActiveThreads(since: lastSync)
        
        var updatedCount = 0
        
        for thread in activeThreads {
            do {
                let newPosts = try await ForumsClient.shared.getNewPosts(for: thread.threadID, since: lastSync)
                
                if !newPosts.isEmpty {
                    try await updatePostsInBackground(newPosts, for: thread)
                    updatedCount += newPosts.count
                }
                
            } catch {
                logger.error("Failed to sync posts for thread \(thread.threadID): \(error)")
                // Continue with other threads
            }
        }
        
        return updatedCount
    }
    
    private func syncBookmarkUpdates(since lastSync: Date) async throws -> Int {
        guard let currentUser = getCurrentUser() else { return 0 }
        
        do {
            let serverBookmarks = try await ForumsClient.shared.getBookmarkedThreads(since: lastSync)
            let localBookmarks = Set(currentUser.bookmarkedThreads.map { $0.threadID })
            
            var updatedCount = 0
            
            // Find threads to add/remove
            let serverBookmarkIDs = Set(serverBookmarks.map { $0.threadID })
            
            let toAdd = serverBookmarkIDs.subtracting(localBookmarks)
            let toRemove = localBookmarks.subtracting(serverBookmarkIDs)
            
            // Update bookmarks
            for threadID in toAdd {
                if let thread = findThread(by: threadID) {
                    currentUser.bookmarkedThreads.insert(thread)
                    thread.isBookmarked = true
                    updatedCount += 1
                }
            }
            
            for threadID in toRemove {
                if let thread = findThread(by: threadID) {
                    currentUser.bookmarkedThreads.remove(thread)
                    thread.isBookmarked = false
                    updatedCount += 1
                }
            }
            
            if updatedCount > 0 {
                try context.save()
            }
            
            return updatedCount
            
        } catch {
            logger.error("Failed to sync bookmarks: \(error)")
            throw error
        }
    }
    
    private func getThreadsNeedingUpdate(since date: Date) -> [Thread] {
        return Thread.fetch(in: context) {
            $0.predicate = NSPredicate(format: "lastModifiedDate < %@ OR lastModifiedDate == nil", date as NSDate)
            $0.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            $0.fetchLimit = 100 // Limit to prevent overwhelming sync
        }
    }
    
    private func getActiveThreads(since date: Date) -> [Thread] {
        // Get threads that might have new posts
        return Thread.fetch(in: context) {
            $0.predicate = NSPredicate(format: "isBookmarked == YES OR lastPostDate >= %@", 
                                     date.addingTimeInterval(-24 * 60 * 60) as NSDate)
            $0.sortDescriptors = [NSSortDescriptor(key: "lastPostDate", ascending: false)]
            $0.fetchLimit = 50
        }
    }
    
    private func updateThreadsInBackground(_ threads: [UpdatedThread]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    for updatedThread in threads {
                        if let thread = self.findThread(by: updatedThread.threadID) {
                            thread.title = updatedThread.title
                            thread.numberOfPosts = Int32(updatedThread.postCount)
                            thread.lastPostDate = updatedThread.lastPostDate
                            thread.totalUnreadPosts = Int32(updatedThread.unreadCount)
                        }
                    }
                    
                    try self.context.save()
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updatePostsInBackground(_ posts: [NewPost], for thread: Thread) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    for newPost in posts {
                        let post = Post.insert(into: self.context)
                        post.postID = newPost.postID
                        post.postIndex = Int32(newPost.postIndex)
                        post.innerHTML = newPost.content
                        post.postDate = newPost.postDate
                        post.thread = thread
                        
                        if let authorData = newPost.author {
                            post.author = self.getOrCreateUser(userID: authorData.userID, 
                                                             username: authorData.username)
                        }
                    }
                    
                    // Update thread post count
                    thread.numberOfPosts = Int32(thread.posts.count)
                    
                    try self.context.save()
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### 2. Conflict Resolution

Handle conflicts between local and server state:

```swift
// ConflictResolver.swift - Handle sync conflicts
class ConflictResolver {
    private let context: NSManagedObjectContext
    
    enum ConflictResolutionStrategy {
        case serverWins      // Server data overwrites local
        case localWins       // Local data overwrites server  
        case merge           // Attempt to merge changes
        case askUser         // Present choice to user
    }
    
    enum ConflictType {
        case readStatus(thread: Thread, localSeen: Int32, serverSeen: Int32)
        case bookmark(thread: Thread, localBookmarked: Bool, serverBookmarked: Bool)
        case draft(draftID: UUID, localContent: String, serverContent: String)
    }
    
    struct ConflictResolution {
        let conflictType: ConflictType
        let strategy: ConflictResolutionStrategy
        let resolution: Any // Result of conflict resolution
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func resolveConflicts(_ conflicts: [ConflictType]) async -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts {
            let strategy = determineStrategy(for: conflict)
            let resolution = await resolveConflict(conflict, strategy: strategy)
            resolutions.append(resolution)
        }
        
        return resolutions
    }
    
    private func determineStrategy(for conflict: ConflictType) -> ConflictResolutionStrategy {
        switch conflict {
        case .readStatus:
            // For read status, use the maximum (most permissive)
            return .merge
            
        case .bookmark:
            // For bookmarks, prefer local state (user's recent action)
            return .localWins
            
        case .draft:
            // For drafts, ask user to choose
            return .askUser
        }
    }
    
    private func resolveConflict(_ conflict: ConflictType, strategy: ConflictResolutionStrategy) async -> ConflictResolution {
        switch conflict {
        case .readStatus(let thread, let localSeen, let serverSeen):
            let resolution = await resolveReadStatusConflict(
                thread: thread,
                localSeen: localSeen,
                serverSeen: serverSeen,
                strategy: strategy
            )
            return ConflictResolution(conflictType: conflict, strategy: strategy, resolution: resolution)
            
        case .bookmark(let thread, let localBookmarked, let serverBookmarked):
            let resolution = await resolveBookmarkConflict(
                thread: thread,
                localBookmarked: localBookmarked,
                serverBookmarked: serverBookmarked,
                strategy: strategy
            )
            return ConflictResolution(conflictType: conflict, strategy: strategy, resolution: resolution)
            
        case .draft(let draftID, let localContent, let serverContent):
            let resolution = await resolveDraftConflict(
                draftID: draftID,
                localContent: localContent,
                serverContent: serverContent,
                strategy: strategy
            )
            return ConflictResolution(conflictType: conflict, strategy: strategy, resolution: resolution)
        }
    }
    
    private func resolveReadStatusConflict(
        thread: Thread,
        localSeen: Int32,
        serverSeen: Int32,
        strategy: ConflictResolutionStrategy
    ) async -> Int32 {
        
        switch strategy {
        case .serverWins:
            thread.seenPosts = serverSeen
            thread.totalUnreadPosts = max(0, thread.numberOfPosts - serverSeen)
            return serverSeen
            
        case .localWins:
            // Keep local state, sync to server
            try? await ForumsClient.shared.markThreadAsRead(threadID: thread.threadID, upToPost: localSeen)
            return localSeen
            
        case .merge:
            // Use the maximum (most posts read)
            let maxSeen = max(localSeen, serverSeen)
            thread.seenPosts = maxSeen
            thread.totalUnreadPosts = max(0, thread.numberOfPosts - maxSeen)
            
            // Sync the merged state to server if different
            if maxSeen != serverSeen {
                try? await ForumsClient.shared.markThreadAsRead(threadID: thread.threadID, upToPost: maxSeen)
            }
            
            return maxSeen
            
        case .askUser:
            // For read status, we typically don't ask user - just merge
            return await resolveReadStatusConflict(thread: thread, localSeen: localSeen, serverSeen: serverSeen, strategy: .merge)
        }
    }
    
    private func resolveBookmarkConflict(
        thread: Thread,
        localBookmarked: Bool,
        serverBookmarked: Bool,
        strategy: ConflictResolutionStrategy
    ) async -> Bool {
        
        switch strategy {
        case .serverWins:
            thread.isBookmarked = serverBookmarked
            if let currentUser = getCurrentUser() {
                if serverBookmarked {
                    currentUser.bookmarkedThreads.insert(thread)
                } else {
                    currentUser.bookmarkedThreads.remove(thread)
                }
            }
            return serverBookmarked
            
        case .localWins:
            // Keep local state, sync to server
            if localBookmarked {
                try? await ForumsClient.shared.addBookmark(threadID: thread.threadID)
            } else {
                try? await ForumsClient.shared.removeBookmark(threadID: thread.threadID)
            }
            return localBookmarked
            
        case .merge:
            // For bookmarks, prefer adding over removing (safer)
            let merged = localBookmarked || serverBookmarked
            thread.isBookmarked = merged
            
            if let currentUser = getCurrentUser() {
                if merged {
                    currentUser.bookmarkedThreads.insert(thread)
                } else {
                    currentUser.bookmarkedThreads.remove(thread)
                }
            }
            
            // Sync merged state if different from server
            if merged != serverBookmarked {
                if merged {
                    try? await ForumsClient.shared.addBookmark(threadID: thread.threadID)
                } else {
                    try? await ForumsClient.shared.removeBookmark(threadID: thread.threadID)
                }
            }
            
            return merged
            
        case .askUser:
            return await presentBookmarkChoiceToUser(thread: thread, localBookmarked: localBookmarked, serverBookmarked: serverBookmarked)
        }
    }
    
    private func resolveDraftConflict(
        draftID: UUID,
        localContent: String,
        serverContent: String,
        strategy: ConflictResolutionStrategy
    ) async -> String {
        
        switch strategy {
        case .serverWins:
            return serverContent
            
        case .localWins:
            return localContent
            
        case .merge:
            // For drafts, merging is complex - fallback to asking user
            return await presentDraftChoiceToUser(draftID: draftID, localContent: localContent, serverContent: serverContent)
            
        case .askUser:
            return await presentDraftChoiceToUser(draftID: draftID, localContent: localContent, serverContent: serverContent)
        }
    }
    
    @MainActor
    private func presentBookmarkChoiceToUser(thread: Thread, localBookmarked: Bool, serverBookmarked: Bool) async -> Bool {
        // Present UI choice to user
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Bookmark Conflict",
                message: "There's a conflict with the bookmark status for \"\(thread.title)\". Which would you prefer?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: localBookmarked ? "Keep Bookmarked" : "Keep Unbookmarked", style: .default) { _ in
                continuation.resume(returning: localBookmarked)
            })
            
            alert.addAction(UIAlertAction(title: serverBookmarked ? "Server: Bookmarked" : "Server: Unbookmarked", style: .default) { _ in
                continuation.resume(returning: serverBookmarked)
            })
            
            // Present alert (implementation depends on current UI context)
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
    
    @MainActor
    private func presentDraftChoiceToUser(draftID: UUID, localContent: String, serverContent: String) async -> String {
        // Present UI choice to user for draft content
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Draft Conflict",
                message: "There are conflicting versions of your draft. Which would you like to keep?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Keep Local Version", style: .default) { _ in
                continuation.resume(returning: localContent)
            })
            
            alert.addAction(UIAlertAction(title: "Use Server Version", style: .default) { _ in
                continuation.resume(returning: serverContent)
            })
            
            alert.addAction(UIAlertAction(title: "Merge Both", style: .default) { _ in
                let merged = "\(localContent)\n\n--- Server Version ---\n\(serverContent)"
                continuation.resume(returning: merged)
            })
            
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
}
```

## SwiftUI Integration

### 1. Offline-Aware SwiftUI Views

SwiftUI views that adapt to offline state:

```swift
// OfflineAwareViews.swift - SwiftUI offline integration
struct OfflineAwareThreadListView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var cacheManager: OfflineCacheManager
    
    let forum: Forum
    
    @FetchRequest private var threads: FetchedResults<Thread>
    
    init(forum: Forum) {
        self.forum = forum
        self._cacheManager = StateObject(wrappedValue: OfflineCacheManager(context: forum.managedObjectContext!))
        
        _threads = FetchRequest(
            entity: Thread.entity(),
            sortDescriptors: [NSSortDescriptor(key: "lastPostDate", ascending: false)],
            predicate: NSPredicate(format: "forum == %@", forum)
        )
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Offline indicator
                if !networkMonitor.isConnected {
                    OfflineIndicatorView()
                }
                
                List(threads) { thread in
                    ThreadRowView(thread: thread)
                        .opacity(isThreadCached(thread) ? 1.0 : 0.6)
                        .overlay(
                            // Cache indicator
                            HStack {
                                Spacer()
                                if isThreadCached(thread) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        )
                }
                .refreshable {
                    if networkMonitor.isConnected {
                        await refreshContent()
                    } else {
                        // Show offline message
                        showOfflineRefreshMessage()
                    }
                }
            }
            .navigationTitle(forum.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cache") {
                        cacheForumContent()
                    }
                    .disabled(!networkMonitor.isConnected)
                }
            }
        }
    }
    
    private func isThreadCached(_ thread: Thread) -> Bool {
        // Check if thread has cached content
        return thread.value(forKey: "lastCachedDate") as? Date != nil
    }
    
    private func refreshContent() async {
        do {
            try await ForumsClient.shared.loadThreads(in: forum)
        } catch {
            logger.error("Failed to refresh threads: \(error)")
        }
    }
    
    private func showOfflineRefreshMessage() {
        // Show offline refresh message
    }
    
    private func cacheForumContent() {
        Task {
            await cacheManager.cacheForumContent(forum)
        }
    }
}

struct OfflineIndicatorView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text("Offline - Showing cached content")
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
    }
}
```

The offline support system ensures Awful.app remains functional without network connectivity while providing seamless synchronization when connectivity is restored.