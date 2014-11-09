//  Forum.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(Forum)
class Forum: AwfulManagedObject {

    @NSManaged var canPost: Bool
    @NSManaged var forumID: String
    @NSManaged var index: Int32
    @NSManaged var lastFilteredRefresh: NSDate?
    @NSManaged var lastRefresh: NSDate?
    @NSManaged var name: String?
    
    @NSManaged var childForums: NSMutableSet /* Forum via parentForum */
    @NSManaged var group: ForumGroup?
    @NSManaged var parentForum: Forum /* via childForums */
    @NSManaged var secondaryThreadTags: NSMutableOrderedSet /* ThreadTag via secondaryForums */
    @NSManaged var threads: NSMutableSet /* Thread */
    @NSManaged var threadTags: NSMutableOrderedSet /* ThreadTag via forums */
}

extension Forum {
    class func fetchOrInsertForumInManagedObjectContext(context: NSManagedObjectContext, withID forumID: String) -> Forum {
        if let forum = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "forumID = %@", forumID)) {
            return forum
        } else {
            let forum = insertInManagedObjectContext(context)
            forum.forumID = forumID
            return forum
        }
    }
}

@objc(ForumGroup)
class ForumGroup: AwfulManagedObject {

    @NSManaged var groupID: String
    @NSManaged var index: Int32
    @NSManaged var name: String?
    
    @NSManaged var forums: NSMutableSet /* Forum */
}

extension ForumGroup {
    class func firstOrNewForumGroupWithID(groupID: String, inManagedObjectContext context: NSManagedObjectContext) -> ForumGroup {
        if let group = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "groupID = %@", groupID)) {
            return group
        } else {
            let group = insertInManagedObjectContext(context)
            group.groupID = groupID
            return group
        }
    }
}
