//  AwfulManagedObject.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

/// A slightly more convenient NSManagedObject for entities with a custom class.
public class AwfulManagedObject: NSManagedObject {
    public class func entityName() -> String {
        return NSStringFromClass(self)
    }
    
    /// Convenience factory method for creating managed objects and calling their awakeFromInitialInsert() method.
    public class func insertIntoManagedObjectContext(context: NSManagedObjectContext) -> Self {
        let entity = NSEntityDescription.entityForName(entityName(), inManagedObjectContext: context)!
        let object = self.init(entity: entity, insertIntoManagedObjectContext: context)
        object.awakeFromInitialInsert()
        return object
    }
    
    /// Called *once*, after the first insertion into a managed object context (contrast to awakeFromInsert(), which can get called multiple times), making awakeFromInitialInsert() a good time to set up necessary relationships.
    func awakeFromInitialInsert() {
        // noop
    }
    
    // Adds `required` so that insertIntoManagedObjectContext(:) works.
    required override public init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
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
        entityName = coder.decodeObjectForKey(entityNameKey) as! String
        super.init()
    }
    
    public func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(entityName, forKey: entityNameKey)
        for key in keys {
            coder.encodeObject(valueForKey(key), forKey: key)
        }
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }
    
    public override func isEqual(object: AnyObject?) -> Bool {
        if let other = object as? AwfulObjectKey {
            if other.entityName != entityName {
                return false
            }
            for key in keys {
                let otherValue = other.valueForKey(key) as! NSObject!
                let value = valueForKey(key) as! NSObject!
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
        if keys.count == 1 {
            let value = valueForKey(keys[0]) as! NSObject!
            hash ^= value.hash
        }
        return hash
    }
}

private let entityNameKey = "entityName"

private extension AwfulObjectKey {
    var predicate: NSPredicate {
        let subpredicates: [NSPredicate] = keys.reduce([]) { accum, key in
            if let value = self.valueForKey(key) as? NSObject {
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
                if let value: AnyObject = objectKey.valueForKey(key) {
                    accum[key]!.append(value)
                }
            }
        }
        return accum
    }
}

extension AwfulManagedObject {
    public var objectKey: AwfulObjectKey {
        fatalError("subclass implementation please")
    }
    
    public class func existingObjectForKey(objectKey: AwfulObjectKey, inManagedObjectContext context: NSManagedObjectContext) -> AnyObject? {
        let request = NSFetchRequest(entityName: objectKey.entityName)
        request.predicate = objectKey.predicate
        request.fetchLimit = 1
        var results : [AwfulManagedObject] = []
        do {
            results = try context.executeFetchRequest(request) as! [AwfulManagedObject]
        }
        catch {
            print("error fetching: \(error)")
            
        }
        return results.first
    }
    
    public class func objectForKey(objectKey: AwfulObjectKey, inManagedObjectContext context: NSManagedObjectContext) -> AnyObject {
        var object = existingObjectForKey(objectKey, inManagedObjectContext: context) as! AwfulManagedObject!
        if object == nil {
            object = insertIntoManagedObjectContext(context)
        }
        object.applyObjectKey(objectKey)
        return object
    }
    
    func applyObjectKey(objectKey: AwfulObjectKey) {
        for key in objectKey.keys {
            if let value: AnyObject = objectKey.valueForKey(key) {
                setValue(value, forKey: key)
            }
        }
    }
    
    /**
    Returns an array of objects of the class's entity matching the objectKeys.
    
    New objects are inserted as necessary, and only a single fetch is executed by the managedObjectContext. The returned array is sorted in the same order as objectKeys. Duplicate (or effectively duplicate) items in objectKeys is no problem and are maintained in the returned array.
    */
    public class func objectsForKeys(objectKeys: [AwfulObjectKey], inManagedObjectContext context: NSManagedObjectContext) -> [AwfulManagedObject] {
        precondition(!objectKeys.isEmpty)
        
        let request = NSFetchRequest(entityName: entityName())
        let aggregateValues = objectKeys[0].dynamicType.valuesForKeysInObjectKeys(objectKeys)
        var subpredicates = [NSPredicate]()
        for (key, values) in aggregateValues {
            subpredicates.append(NSPredicate(format: "%K IN %@", key, values))
        }
        if subpredicates.count == 1 {
            request.predicate = subpredicates[0]
        } else {
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates:subpredicates)
        }
        
        var results : [AwfulManagedObject] = []
        do {
            results = try context.executeFetchRequest(request) as! [AwfulManagedObject]
        }
        catch {
            print("error fetching \(error)")
            
        }

        
        var existingByKey = [AwfulObjectKey: AwfulManagedObject](minimumCapacity: results.count)
        for object in results {
            existingByKey[object.objectKey] = object
        }
        
        return objectKeys.map { objectKey in
            if let existing = existingByKey[objectKey] {
                return existing
            } else {
                let object = self.insertIntoManagedObjectContext(context)
                object.applyObjectKey(objectKey)
                existingByKey[object.objectKey] = object
                return object
            }
        }
    }
}
