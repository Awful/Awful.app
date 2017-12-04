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
    
    @NSManaged public var childForums: Set<Forum> /* via parentForum */
    @NSManaged public var group: ForumGroup?
    @NSManaged public var parentForum: Forum? /* via childForums */
    @NSManaged var secondaryThreadTags: NSMutableOrderedSet /* ThreadTag via secondaryForums */
    @NSManaged public var threads: Set<AwfulThread>
    @NSManaged public var threadTags: NSMutableOrderedSet /* ThreadTag via forums */
    @NSManaged public private(set) var metadata: ForumMetadata
    
    override public func awakeFromInitialInsert() {
        metadata = ForumMetadata.insertIntoManagedObjectContext(context: managedObjectContext!)
    }
}

@objc(ForumKey)
public final class ForumKey: AwfulObjectKey {
    @objc let forumID: String
    
    public init(forumID: String) {
        assert(!forumID.isEmpty)
        self.forumID = forumID
        super.init(entityName: Forum.entityName())
    }
    
    public required init?(coder: NSCoder) {
        forumID = coder.decodeObject(forKey: forumIDKey) as! String
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
    
    @NSManaged public var forums: Set<Forum>
    
    /**
     A transient attribute suitable for use as an `NSFetchedResultsController`'s `sectionNameKeyPath`. Has the same ordering as `index`, if that's more convenient.
     
     Takes the format `"000000 Main"`, where `000000` is the `index` (encoded in base62 and padded to six digits (enough to encode `Int32.max`)) and `Main` is the `name`.
     */
    @objc public var sectionIdentifier: String {
        willAccessValue(forKey: #keyPath(ForumGroup.index))
        willAccessValue(forKey: #keyPath(ForumGroup.name))
        defer {
            didAccessValue(forKey: #keyPath(ForumGroup.name))
            didAccessValue(forKey: #keyPath(ForumGroup.index))
        }
        
        let encodedIndex = base62Encode(index)
        let padding = String(repeating: "0", count: ForumGroup.sectionIdentifierIndexLength - encodedIndex.count)
        return "\(padding)\(encodedIndex) \(name ?? "")"
    }
    
    /// The number of characters in the index part of `sectionIdentifier`. Provided for easy chopping of an `NSFetchedResultsController`'s section name into a proper display name.
    public class var sectionIdentifierIndexLength: Int {
        // Character length of Int32.max in base62.
        return 6
    }
    
    @objc class func keyPathsForValuesAffectingSectionIdentifier() -> Set<String> {
        return [#keyPath(ForumGroup.index), #keyPath(ForumGroup.name)]
    }
}

@objc(ForumGroupKey)
public final class ForumGroupKey: AwfulObjectKey {
    let groupID: String
    
    public init(groupID: String) {
        self.groupID = groupID
        super.init(entityName: ForumGroup.entityName())
    }
    
    public required init?(coder: NSCoder) {
        groupID = coder.decodeObject(forKey: groupIDKey) as! String
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
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName())
        request.predicate = NSPredicate(format: "forum.forumID IN %@", forumIDs)
        var results : [ForumMetadata] = []
        var success : Bool = false
        do {
            results = try context.fetch(request) as! [ForumMetadata]
            success = true;
        }
        catch {
            print("error fetching: \(error)")
        }
        assert(success, "error fetching, crashing")
        return results
    }
}
