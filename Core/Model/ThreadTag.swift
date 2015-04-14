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
    // This silly casting works around an API change between Xcode 6.1 and Xcode 6.1.1, wherein NSURL.lastPathComponent went from returning `String` to returning `String?`. The cast allows compilation on either version.
    return (URL.lastPathComponent as String!).stringByDeletingPathExtension
}

@objc(ThreadTagKey)
public final class ThreadTagKey: AwfulObjectKey {
    public let imageName: String?
    public let threadTagID: String?
    
    public init(imageName: String!, threadTagID: String!) {
        let imageName = nilIfEmpty(imageName)
        let threadTagID = nilIfEmpty(threadTagID)
        precondition(imageName != nil || threadTagID != nil)
        
        self.imageName = imageName
        self.threadTagID = threadTagID
        super.init(entityName: ThreadTag.entityName())
    }
    
    public convenience init(imageURL: NSURL, threadTagID: String?) {
        self.init(imageName: imageNameFromURL(imageURL), threadTagID: threadTagID)
    }
    
    public required init(coder: NSCoder) {
        imageName = coder.decodeObjectForKey(imageNameKey) as! String?
        threadTagID = coder.decodeObjectForKey(threadTagIDKey) as! String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [imageNameKey, threadTagIDKey]
    }
}
private let imageNameKey = "imageName"
private let threadTagIDKey = "threadTagID"

extension ThreadTag {
    public override var objectKey: ThreadTagKey {
        return ThreadTagKey(imageName: imageName, threadTagID: threadTagID)
    }
}
