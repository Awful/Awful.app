//  ThreadTag.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ThreadTag)
public class ThreadTag: AwfulManagedObject, Managed {
    public static var entityName: String { "ThreadTag" }

    @NSManaged public var imageName: String?
    @NSManaged public var threadTagID: String?

    @NSManaged var announcements: Set<Announcement>
    @NSManaged var forums: Set<Forum> /* via threadTags */
    @NSManaged var messages: Set<PrivateMessage>
    @NSManaged var secondaryForums: Set<Forum> /* via secondaryThreadTags */
    @NSManaged var secondaryThreads: Set<AwfulThread> /* via secondaryThreadTag */
    @NSManaged var threads: Set<AwfulThread> /* via threadTag */

    public override var objectKey: ThreadTagKey {
        .init(imageName: imageName, threadTagID: threadTagID)
    }
}

extension ThreadTag {
    func setURL(url: URL) {
        imageName = ThreadTag.imageName(from: url)
    }

    public static func imageName(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}

@objc(ThreadTagKey)
public final class ThreadTagKey: AwfulObjectKey {
    @objc public let imageName: String?
    @objc public let threadTagID: String?
    
    @objc public init(imageName: String?, threadTagID: String?) {
        let imageName = imageName.flatMap { $0.isEmpty ? nil : $0 }
        let threadTagID = threadTagID.flatMap { $0.isEmpty ? nil : $0 }
        precondition(imageName != nil || threadTagID != nil)
        
        self.imageName = imageName
        self.threadTagID = threadTagID
        super.init(entityName: ThreadTag.entityName)
    }
    
    @objc public convenience init(imageURL: URL, threadTagID: String?) {
        self.init(imageName: ThreadTag.imageName(from: imageURL), threadTagID: threadTagID)
    }
    
    public required init?(coder: NSCoder) {
        imageName = coder.decodeObject(forKey: imageNameKey) as! String?
        threadTagID = coder.decodeObject(forKey: threadTagIDKey) as! String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [imageNameKey, threadTagIDKey]
    }
}
private let imageNameKey = "imageName"
private let threadTagIDKey = "threadTagID"
