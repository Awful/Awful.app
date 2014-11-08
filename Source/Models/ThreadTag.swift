//  ThreadTag.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ThreadTag)
class ThreadTag: AwfulManagedObject {

    @NSManaged var imageName: String?
    @NSManaged var threadTagID: String?
    
    @NSManaged var forums: NSMutableSet /* AwfulForum via threadTags */
    @NSManaged var messages: NSMutableSet /* PrivateMessage */
    @NSManaged var secondaryForums: NSMutableSet /* AwfulForum via secondaryThreadTags */
    @NSManaged var secondaryThreads: NSMutableSet /* AwfulThread via secondaryThreadTag */
    @NSManaged var threads: NSMutableSet /* AwfulThread via threadTag */
}

extension ThreadTag {
    func setURL(URL: NSURL) {
        imageName = imageNameFromURL(URL)
    }
}

private func imageNameFromURL(URL: NSURL) -> String {
    return URL.lastPathComponent.stringByDeletingPathExtension
}

extension ThreadTag {
    class func firstOrNewThreadTagWithID(threadTagID: String!, imageName: String!, inManagedObjectContext context: NSManagedObjectContext) -> ThreadTag {
        var tag: ThreadTag!
        if (!empty(threadTagID)) {
            tag = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "threadTagID = %@", threadTagID))
        } else if (!empty(imageName)) {
            tag = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "imageName = %@", imageName))
        } else {
            fatalError("need either a tagID (got \(threadTagID)) or an imageName (got \(imageName))")
        }
        if (tag == nil) {
            tag = insertInManagedObjectContext(context)
        }
        if (!empty(threadTagID)) {
            tag.threadTagID = threadTagID
        }
        if (!empty(imageName)) {
            tag.imageName = imageName
        }
        return tag
    }
    
    class func firstOrNewThreadTagWithID(threadTagID: String?, threadTagURL: NSURL?, inManagedObjectContext context: NSManagedObjectContext) -> ThreadTag {
        var imageName: String?
        if let threadTagURL = threadTagURL {
            imageName = imageNameFromURL(threadTagURL)
        }
        return firstOrNewThreadTagWithID(threadTagID, imageName: imageName, inManagedObjectContext: context)
    }
}

private func empty(string: String?) -> Bool {
    if let string = string {
        return string.isEmpty
    } else {
        return true
    }
}
