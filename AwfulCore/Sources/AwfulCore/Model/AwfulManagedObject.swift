//  AwfulManagedObject.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

/// A slightly more convenient NSManagedObject for entities with a custom class.
public class AwfulManagedObject: NSManagedObject, @unchecked Sendable {
    public var objectKey: AwfulObjectKey {
        fatalError("subclass implementation please")
    }
}

/// An object key uniquely identifies an AwfulManagedObject, but (unlike NSManagedObjectID) in an Awful-specific away.
public class AwfulObjectKey: NSObject, NSCoding, NSCopying {
    let entityName: String
    var keys: [String] {
        fatalError("subclass implementation please")
    }
    
    init(entityName: String) {
        self.entityName = entityName
    }
    
    public required init?(coder: NSCoder) {
        entityName = coder.decodeObject(forKey: entityNameKey) as! String
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(entityName, forKey: entityNameKey)
        for key in keys {
            coder.encode(value(forKey: key), forKey: key)
        }
    }
    
    public func copy(with: NSZone?) -> Any {
        return self
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? AwfulObjectKey {
            if other.entityName != entityName {
                return false
            }
            for key in keys {
                let otherValue = other.value(forKey: key) as! NSObject?
                let value = self.value(forKey: key) as! NSObject?
                if otherValue != nil && value != nil && otherValue != value {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    public override var hash: Int {
        var hash = entityName.hash
        if let key = keys.first, let value = self.value(forKey: key) as? AnyHashable {
            hash ^= value.hashValue
        }
        return hash
    }
}

private let entityNameKey = "entityName"

private extension AwfulObjectKey {
    var predicate: NSPredicate {
        let subpredicates: [NSPredicate] = keys.reduce([]) { accum, key in
            if let value = self.value(forKey: key) as? NSObject {
                return accum + [NSPredicate(format: "%K == %@", key, value)]
            } else {
                return accum
            }
        }
        if subpredicates.count == 1 {
            return subpredicates[0]
        } else {
            return NSCompoundPredicate(orPredicateWithSubpredicates:subpredicates)
        }
    }
    
    /// Turns a collection of object keys into a dictionary mapping the important KVC-keys to the non-nil values of the objectKeys. For example, the return value for some ForumKeys might be ["forumID": ["25", "26"]]
    class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        precondition(!objectKeys.isEmpty)
        
        var accum = [String: [AnyObject]]()
        let keys = objectKeys[0].keys
        for key in keys {
            accum[key] = []
        }
        for objectKey in objectKeys {
            for key in keys {
                if let value: AnyObject = objectKey.value(forKey: key) as AnyObject? {
                    accum[key]!.append(value)
                }
            }
        }
        return accum
    }
}

extension Managed where Self: AwfulManagedObject {
    public static func existingObjectForKey(
        objectKey: AwfulObjectKey,
        in context: NSManagedObjectContext
    ) -> Self? {
        precondition(objectKey.entityName == entityName)
        return findOrFetch(in: context, matching: objectKey.predicate)
    }
    
    public static func objectForKey(
        objectKey: AwfulObjectKey,
        in context: NSManagedObjectContext
    ) -> Self {
        precondition(objectKey.entityName == entityName)
        return findOrCreate(in: context, matching: objectKey.predicate) {
            $0.applyObjectKey(objectKey: objectKey)
        }
    }
    
    func applyObjectKey(objectKey: AwfulObjectKey) {
        for key in objectKey.keys {
            if let value = objectKey.value(forKey: key) as AnyObject? {
                setValue(value, forKey: key)
            }
        }
    }
    
    /**
    Returns an array of objects of the class's entity matching the objectKeys.
    
    New objects are inserted as necessary, and only a single fetch is executed by the managedObjectContext. The returned array is sorted in the same order as objectKeys. Duplicate (or effectively duplicate) items in objectKeys is no problem and are maintained in the returned array.
    */
    public static func objectsForKeys(
        objectKeys: [AwfulObjectKey],
        in context: NSManagedObjectContext
    ) -> [Self] {
        precondition(objectKeys.allSatisfy { $0.entityName == entityName })

        if objectKeys.isEmpty { return [] }

        var existingByKey = Dictionary(
            fetch(in: context) {
            $0.predicate = .or(
                type(of: objectKeys[0])
                    .valuesForKeysInObjectKeys(objectKeys: objectKeys)
                    .map { .init(format: "%K IN %@", $0, $1) }
            )
            }.map { ($0.objectKey, $0) },
            uniquingKeysWith: { $1 }
        )

        return objectKeys.map { objectKey in
            if let existing = existingByKey[objectKey] {
                return existing
            } else {
                let object = insert(into: context)
                object.applyObjectKey(objectKey: objectKey)
                existingByKey[object.objectKey] = object
                return object
            }
        }
    }
}
