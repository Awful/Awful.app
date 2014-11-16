//  ThreadTag.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ThreadTag)
public class ThreadTag: AwfulManagedObject {

    @NSManaged public var imageName: String?
    @NSManaged public var threadTagID: String?
    
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
    return URL.lastPathComponent!.stringByDeletingPathExtension
}

class ThreadTagKey: AwfulObjectKey {
    let imageName: String?
    let threadTagID: String?
    init(imageName: String!, threadTagID: String!) {
        assert(!empty(imageName) || !empty(threadTagID))
        self.imageName = imageName
        self.threadTagID = threadTagID
        super.init(entityName: ThreadTag.entityName())
    }
    required init(coder: NSCoder) {
        imageName = coder.decodeObjectForKey(imageNameKey) as String?
        threadTagID = coder.decodeObjectForKey(threadTagIDKey) as String?
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        if let imageName = imageName {
            coder.encodeObject(imageName, forKey: imageNameKey)
        }
        if let threadTagID = threadTagID {
            coder.encodeObject(threadTagID, forKey: threadTagIDKey)
        }
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? ThreadTagKey {
            if threadTagID != nil && other.threadTagID != nil {
                return threadTagID! == other.threadTagID!
            } else if imageName != nil && other.imageName != nil {
                return imageName! == other.imageName!
            }
        }
        return false
    }
    override class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        var mapping = [
            "imageName": [AnyObject](),
            "threadTagID": [AnyObject]()
        ]
        for key in objectKeys as [ThreadTagKey] {
            if let imageName = key.imageName {
                mapping["imageName"]!.append(imageName)
            }
            if let threadTagID = key.threadTagID {
                mapping["threadTagID"]!.append(threadTagID)
            }
        }
        return mapping
    }
}

private let imageNameKey = "imageName"
private let threadTagIDKey = "threadTagID"

extension ThreadTagKey {
    convenience init(imageURL: NSURL, threadTagID: String?) {
        self.init(imageName: imageNameFromURL(imageURL), threadTagID: threadTagID)
    }
}

extension ThreadTag {
    override var objectKey: ThreadTagKey {
        get { return ThreadTagKey(imageName: imageName, threadTagID: threadTagID) }
    }
    
    override func applyObjectKey(objectKey: AwfulObjectKey) {
        let objectKey = objectKey as ThreadTagKey
        if (!empty(objectKey.threadTagID)) {
            threadTagID = objectKey.threadTagID
        }
        if (!empty(objectKey.imageName)) {
            imageName = objectKey.imageName
        }
    }
    
    class func objectForKey(threadTagKey: ThreadTagKey, inManagedObjectContext context: NSManagedObjectContext) -> ThreadTag {
        var tag: ThreadTag!
        if (!empty(threadTagKey.threadTagID)) {
            tag = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "threadTagID = %@", threadTagKey.threadTagID!))
        } else {
            tag = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "imageName = %@", threadTagKey.imageName!))
        }
        if (tag == nil) {
            tag = insertInManagedObjectContext(context)
        }
        tag.applyObjectKey(threadTagKey)
        return tag
    }
}

private func empty(string: String?) -> Bool {
    if let string = string {
        return string.isEmpty
    } else {
        return true
    }
}
