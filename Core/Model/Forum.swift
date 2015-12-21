//  Forum.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

@objc(Forum)
public class Forum: AwfulManagedObject {
    @NSManaged public var canPost: Bool
    @NSManaged public var forumID: String
    @NSManaged public var index: Int32
    @NSManaged public var lastFilteredRefresh: NSDate?
    @NSManaged public var lastRefresh: NSDate?
    @NSManaged public var name: String?
    
    @NSManaged public var childForums: NSMutableSet /* Forum via parentForum */
    @NSManaged public var group: ForumGroup?
    @NSManaged public var parentForum: Forum? /* via childForums */
    @NSManaged var secondaryThreadTags: NSMutableOrderedSet /* ThreadTag via secondaryForums */
    @NSManaged public var threads: NSMutableSet /* Thread */
    @NSManaged public var threadTags: NSMutableOrderedSet /* ThreadTag via forums */
    @NSManaged public private(set) var metadata: ForumMetadata
    
    override public func awakeFromInitialInsert() {
        metadata = ForumMetadata.insertIntoManagedObjectContext(managedObjectContext!)
    }
}

@objc(ForumKey)
public final class ForumKey: AwfulObjectKey {
    let forumID: String
    
    public init(forumID: String) {
        assert(!forumID.isEmpty)
        self.forumID = forumID
        super.init(entityName: Forum.entityName())
    }
    
    public required init?(coder: NSCoder) {
        forumID = coder.decodeObjectForKey(forumIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [forumIDKey]
    }
}
private let forumIDKey = "forumID"

extension Forum {
    public override var objectKey: ForumKey {
        return ForumKey(forumID: forumID)
    }
}

@objc(ForumGroup)
public class ForumGroup: AwfulManagedObject {
    @NSManaged public var groupID: String
    @NSManaged public var index: Int32
    @NSManaged public var name: String?
    
    @NSManaged public var forums: NSMutableSet /* Forum */
}

@objc(ForumGroupKey)
public final class ForumGroupKey: AwfulObjectKey {
    let groupID: String
    
    public init(groupID: String) {
        self.groupID = groupID
        super.init(entityName: ForumGroup.entityName())
    }
    
    public required init?(coder: NSCoder) {
        groupID = coder.decodeObjectForKey(groupIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [groupIDKey]
    }
}
private let groupIDKey = "groupID"

extension ForumGroup {
    public override var objectKey: ForumGroupKey {
        return ForumGroupKey(groupID: groupID)
    }
}

@objc(ForumMetadata)
public class ForumMetadata: AwfulManagedObject {
    @NSManaged public var favorite: Bool
    @NSManaged public var favoriteIndex: Int32
    @NSManaged public var showsChildrenInForumList: Bool
    
    @NSManaged public private(set) var forum: Forum
}

extension ForumMetadata {
    public class func metadataForForumsWithIDs(forumIDs: [String], inManagedObjectContext context: NSManagedObjectContext) -> [ForumMetadata] {
        let request = NSFetchRequest(entityName: entityName())
        request.predicate = NSPredicate(format: "forum.forumID IN %@", forumIDs)
        var results : [ForumMetadata] = []
        var success : Bool = false
        do {
            results = try context.executeFetchRequest(request) as! [ForumMetadata]
            success = true;
        }
        catch {
            print("error fetching: \(error)")
        }
        assert(success, "error fetching, crashing")
        return results
    }
}
