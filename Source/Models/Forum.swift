//  Forum.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(Forum)
public class Forum: AwfulManagedObject {
    @NSManaged public var canPost: Bool
    @NSManaged public var forumID: String
    @NSManaged var index: Int32
    @NSManaged var lastFilteredRefresh: NSDate?
    @NSManaged var lastRefresh: NSDate?
    @NSManaged public var name: String?
    
    @NSManaged public var childForums: NSMutableSet /* Forum via parentForum */
    @NSManaged public var group: ForumGroup?
    @NSManaged public var parentForum: Forum? /* via childForums */
    @NSManaged var secondaryThreadTags: NSMutableOrderedSet /* ThreadTag via secondaryForums */
    @NSManaged var threads: NSMutableSet /* Thread */
    @NSManaged public var threadTags: NSMutableOrderedSet /* ThreadTag via forums */
    @NSManaged private(set) var metadata: ForumMetadata
    
    override var objectKey: ForumKey {
        return ForumKey(forumID: forumID)
    }
    
    override public func awakeFromInitialInsert() {
        metadata = ForumMetadata.insertIntoManagedObjectContext(managedObjectContext!)
    }
}

final class ForumKey: AwfulObjectKey {
    let forumID: String
    
    init(forumID: String) {
        assert(!forumID.isEmpty)
        self.forumID = forumID
        super.init(entityName: Forum.entityName())
    }
    
    required init(coder: NSCoder) {
        forumID = coder.decodeObjectForKey(forumIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [forumIDKey]
    }
}

private let forumIDKey = "forumID"

@objc(ForumGroup)
public class ForumGroup: AwfulManagedObject {
    @NSManaged public var groupID: String
    @NSManaged var index: Int32
    @NSManaged public var name: String?
    
    @NSManaged public var forums: NSMutableSet /* Forum */
    
    override var objectKey: ForumGroupKey {
        return ForumGroupKey(groupID: groupID)
    }
}

final class ForumGroupKey: AwfulObjectKey {
    let groupID: String
    
    init(groupID: String) {
        self.groupID = groupID
        super.init(entityName: ForumGroup.entityName())
    }
    
    required init(coder: NSCoder) {
        groupID = coder.decodeObjectForKey(groupIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [groupIDKey]
    }
}

private let groupIDKey = "groupID"

@objc(ForumMetadata)
class ForumMetadata: AwfulManagedObject {
    @NSManaged var favorite: Bool
    @NSManaged var favoriteIndex: Int32
    @NSManaged var showsChildrenInForumList: Bool
    @NSManaged var visibleInForumList: Bool
    
    @NSManaged private(set) var forum: Forum
}

extension ForumMetadata {
    class func metadataForForumsWithIDs(forumIDs: [String], inManagedObjectContext context: NSManagedObjectContext) -> [ForumMetadata] {
        let request = NSFetchRequest(entityName: entityName())
        request.predicate = NSPredicate(format: "forum.forumID IN %@", forumIDs)
        var error: NSError?
        let results = context.executeFetchRequest(request, error: &error) as! [ForumMetadata]!
        assert(results != nil, "error fetching: \(error!)")
        return results
    }
}
