//  Post.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A single reply to a thread.
@objc(Post)
public class Post: AwfulManagedObject {

    /// Whether the logged-in user can edit the post.
    @NSManaged public var editable: Bool
    
    /// Where the post is located when filtering its thread by the post's author.
    @NSManaged var filteredThreadIndex: Int32
    
    /// Whether the post's author is ignored.
    @NSManaged public var ignored: Bool
    
    /// The HTML body of the post.
    @NSManaged public var innerHTML: String?
    
    /// The last time the cached post data changed.
    @NSManaged var lastModifiedDate: NSDate
    
    /// When the post appeared.
    @NSManaged public var postDate: NSDate?
    
    /// An ID assigned by the Forums that presumably uniquely identifies it.
    @NSManaged public var postID: String
    
    /// Where the post is located in its thread.
    @NSManaged public var threadIndex: Int32
    
    /// Who wrote the post.
    @NSManaged public var author: User?
    
    /// Where the post is located.
    @NSManaged public var thread: Thread?
}

extension Post {
    /// Whether the user has seen the post.
    public var beenSeen: Bool {
        get {
            if let thread = thread {
                return threadIndex > 0 && threadIndex <= thread.seenPosts
            }
            return false
        }
    }
    
    /// Which 40-post page the post is located on.
    public var page: Int {
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

class PostKey: AwfulObjectKey {
    let postID: String
    init(postID: String) {
        assert(!postID.isEmpty)
        self.postID = postID
        super.init(entityName: Post.entityName())
    }
    required init(coder: NSCoder) {
        postID = coder.decodeObjectForKey(postIDKey) as String
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(postID, forKey: postIDKey)
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? PostKey {
            return other.postID == postID
        } else {
            return false
        }
    }
    override var hash: Int {
        get { return super.hash ^ postID.hash }
    }
    override class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        let objectKeys = objectKeys as [PostKey]
        return ["postID": objectKeys.map{$0.postID}]
    }
}

private let postIDKey = "postID"

extension Post {
    override var objectKey: PostKey {
        get { return PostKey(postID: postID) }
    }
    
    override func applyObjectKey(objectKey: AwfulObjectKey) {
        let objectKey = objectKey as PostKey
        postID = objectKey.postID
    }
    
    class func objectWithKey(postKey: PostKey, inManagedObjectContext context: NSManagedObjectContext) -> Post {
        if let post = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "postID = %@", postKey.postID)) {
            return post
        } else {
            let post = insertInManagedObjectContext(context)
            post.applyObjectKey(postKey)
            return post
        }
    }
}
