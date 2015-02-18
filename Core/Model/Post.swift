//  Post.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A single reply to a thread.
@objc(Post)
public class Post: AwfulManagedObject {
    /// Whether the logged-in user can edit the post.
    @NSManaged public var editable: Bool
    
    /// Where the post is located when filtering its thread by the post's author.
    @NSManaged public var filteredThreadIndex: Int32
    
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
        if let thread = thread {
            return threadIndex > 0 && threadIndex <= thread.seenPosts
        }
        return false
    }
    
    /// Which 40-post page the post is located on.
    public var page: Int {
        return pageForIndex(threadIndex)
    }
    
    /// Which 40-post page the post is located on in a thread filtered by the post's author.
    public var singleUserPage: Int {
        return pageForIndex(filteredThreadIndex)
    }
}

private func pageForIndex(index: Int32) -> Int {
    if index <= 0 {
        return 0
    } else {
        return (index - 1) / 40 + 1
    }
}

@objc(PostKey)
public final class PostKey: AwfulObjectKey {
    public let postID: String
    
    public init(postID: String) {
        assert(!postID.isEmpty)
        self.postID = postID
        super.init(entityName: Post.entityName())
    }
    
    public required init(coder: NSCoder) {
        postID = coder.decodeObjectForKey(postIDKey) as String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [postIDKey]
    }
}
private let postIDKey = "postID"

extension Post {
    public override var objectKey: PostKey {
        return PostKey(postID: postID)
    }
}
