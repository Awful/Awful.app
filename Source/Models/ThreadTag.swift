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

final class ThreadTagKey: AwfulObjectKey {
    let imageName: String?
    let threadTagID: String?
    
    init(imageName: String!, threadTagID: String!) {
        let imageName = nilIfEmpty(imageName)
        let threadTagID = nilIfEmpty(threadTagID)
        precondition(imageName != nil || threadTagID != nil)
        
        self.imageName = imageName
        self.threadTagID = threadTagID
        super.init(entityName: ThreadTag.entityName())
    }
    
    required init(coder: NSCoder) {
        imageName = coder.decodeObjectForKey(imageNameKey) as String?
        threadTagID = coder.decodeObjectForKey(threadTagIDKey) as String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [imageNameKey, threadTagIDKey]
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
        return ThreadTagKey(imageName: imageName, threadTagID: threadTagID)
    }
}
