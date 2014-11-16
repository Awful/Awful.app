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
}

class ForumKey: AwfulObjectKey {
    let forumID: String
    init(forumID: String) {
        assert(!forumID.isEmpty)
        self.forumID = forumID
        super.init(entityName: Forum.entityName())
    }
    required init(coder: NSCoder) {
        forumID = coder.decodeObjectForKey(forumIDKey) as String
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(forumID, forKey: forumIDKey)
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? ForumKey {
            return other.forumID == forumID
        } else {
            return false
        }
    }
    override var hash: Int {
        get { return super.hash ^ forumID.hash }
    }
    override class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        let objectKeys = objectKeys as [ForumKey]
        return ["forumID": objectKeys.map{$0.forumID}]
    }
}

private let forumIDKey = "forumID"

extension Forum {
    override var objectKey: ForumKey {
        get {
            return ForumKey(forumID: forumID)
        }
    }
    
    override func applyObjectKey(objectKey: AwfulObjectKey) {
        let objectKey = objectKey as ForumKey
        forumID = objectKey.forumID
    }
    
    class func objectWithKey(objectKey: ForumKey, inManagedObjectContext context: NSManagedObjectContext) -> Forum {
        if let forum = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "forumID = %@", objectKey.forumID)) {
            return forum
        } else {
            let forum = insertInManagedObjectContext(context)
            forum.applyObjectKey(objectKey)
            return forum
        }
    }
    
    override public class func insertInManagedObjectContext(context: NSManagedObjectContext) -> Forum {
        let forum = super.insertInManagedObjectContext(context) as Forum
        forum.metadata = ForumMetadata.insertInManagedObjectContext(context)
        return forum
    }
}

@objc(ForumGroup)
public class ForumGroup: AwfulManagedObject {

    @NSManaged public var groupID: String
    @NSManaged var index: Int32
    @NSManaged public var name: String?
    
    @NSManaged public var forums: NSMutableSet /* Forum */
}

class ForumGroupKey: AwfulObjectKey {
    let groupID: String
    init(groupID: String) {
        self.groupID = groupID
        super.init(entityName: ForumGroup.entityName())
    }
    required init(coder: NSCoder) {
        groupID = coder.decodeObjectForKey(groupIDKey) as String
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(groupID, forKey: groupIDKey)
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? ForumGroupKey {
            return other.groupID == groupID
        } else {
            return false
        }
    }
    override var hash: Int {
        get { return super.hash ^ groupID.hash }
    }
    override class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        let objectKeys = objectKeys as [ForumGroupKey]
        return ["groupID": objectKeys.map{$0.groupID}]
    }
}

extension ForumGroup {
    override var objectKey: ForumGroupKey {
        get { return ForumGroupKey(groupID: groupID) }
    }
    
    override func applyObjectKey(objectKey: AwfulObjectKey) {
        let objectKey = objectKey as ForumGroupKey
        groupID = objectKey.groupID
    }
    
    class func objectForKey(groupKey: ForumGroupKey, inManagedObjectContext context: NSManagedObjectContext) -> ForumGroup {
        if let group = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "groupID = %@", groupKey.groupID)) {
            return group
        } else {
            let group = insertInManagedObjectContext(context)
            group.applyObjectKey(groupKey)
            return group
        }
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
