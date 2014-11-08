//  Post.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A single reply to a thread.
@objc(Post)
class Post: AwfulManagedObject {

    /// Whether the logged-in user can edit the post.
    @NSManaged var editable: Bool
    
    /// Where the post is located when filtering its thread by the post's author.
    @NSManaged var filteredThreadIndex: Int32
    
    /// Whether the post's author is ignored.
    @NSManaged var ignored: Bool
    
    /// The HTML body of the post.
    @NSManaged var innerHTML: String?
    
    /// The last time the cached post data changed.
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged private var primitiveLastModifiedDate: NSDate?
    
    /// When the post appeared.
    @NSManaged var postDate: NSDate?
    
    /// An ID assigned by the Forums that presumably uniquely identifies it.
    @NSManaged var postID: String
    
    /// Where the post is located in its thread.
    @NSManaged var threadIndex: Int32
    
    /// Who wrote the post.
    @NSManaged var author: AwfulUser?
    
    /// Where the post is located.
    @NSManaged var thread: Thread?
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        primitiveLastModifiedDate = NSDate()
    }
}

extension Post {
    /// Whether the user has seen the post.
    var beenSeen: Bool {
        get {
            if let thread = thread {
                return threadIndex > 0 && threadIndex <= thread.seenPosts
            }
            return false
        }
    }
    
    /// Which 40-post page the post is located on.
    var page: Int {
        get { return pageForIndex(threadIndex) }
    }
    
    /// Which 40-post page the post is located on in a thread filtered by the post's author.
    var singleUserPage: Int {
        get { return pageForIndex(filteredThreadIndex) }
    }
}

private func pageForIndex(index: Int32) -> Int {
    if index <= 0 {
        return 0
    } else {
        return (index - 1) / 40 + 1
    }
}

extension Post {
    /// Upserts a Post. Does not save the context if a new Post is inserted.
    class func firstOrNewPostWithPostID(postID: String, inManagedObjectContext context: NSManagedObjectContext) -> Post {
        assert(!postID.isEmpty)
        let post = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "postID = %@", postID))
        if let post = post {
            return post
        } else {
            let post = insertInManagedObjectContext(context)
            post.postID = postID
            return post
        }
    }
}
