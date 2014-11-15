//  AwfulObjectKey.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// An object key uniquely identifies an AwfulManagedObject, but (unlike NSManagedObjectID) in an Awful-specific away.
class AwfulObjectKey: NSObject, NSCoding, NSCopying {

    let entityName: String
    
    init(entityName: String) {
        self.entityName = entityName
    }

    required init(coder: NSCoder) {
        entityName = coder.decodeObjectForKey(entityNameKey) as String
        super.init()
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(entityName, forKey: entityNameKey)
    }
    
    func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        if let other = object as? AwfulObjectKey {
            return other.entityName == entityName
        } else {
            return false
        }
    }
    
    override var hash: Int {
        get { return entityName.hash }
    }
    
    /// Turns a collection of object keys into a dictionary mapping the important KVC-keys to the non-nil values of the objectKeys. For example, the return value for some ForumKeys might be ["forumID": ["25", "26"]]
    class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        fatalError("subclass implementation please")
    }
}

private let entityNameKey = "entityName"

extension AwfulManagedObject {
    var objectKey: AwfulObjectKey {
        get { fatalError("subclass implementation please") }
    }
    
    func applyObjectKey(objectKey: AwfulObjectKey) {
        fatalError("subclass implementation please")
    }
}
