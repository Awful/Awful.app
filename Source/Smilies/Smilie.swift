//  Smilie.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData

public typealias SmiliePrimaryKey = String

public class Smilie: NSManagedObject {

    @NSManaged public var imageData: NSData?
    @NSManaged public var imageURL: NSString?
    @NSManaged public var section: String?
    @NSManaged public var summary: String?
    @NSManaged public var text: SmiliePrimaryKey
    
    public var metadata: SmilieMetadata {
        get {
            let fetchedMetadata = valueForKey("fetchedMetadata") as [SmilieMetadata]
            if !fetchedMetadata.isEmpty {
                return fetchedMetadata[0]
            } else if !text.isEmpty {
                let metadata = NSEntityDescription.insertNewObjectForEntityForName("SmilieMetadata", inManagedObjectContext: managedObjectContext) as SmilieMetadata
                metadata.smilieText = text
                return metadata
            } else {
                fatalError("smilie needs text before you can access its metadata")
            }
        }
    }
    
    public convenience init(managedObjectContext context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Smilie", inManagedObjectContext: context)
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
    }
    
    public class func smilieWithText(text: SmiliePrimaryKey, inContext context: NSManagedObjectContext) -> Smilie? {
        let request = NSFetchRequest(entityName: "Smilie")
        request.predicate = NSPredicate(format: "text = %@", text)
        request.fetchLimit = 1
        var error: NSError?
        let results = context.executeFetchRequest(request, error: &error)
        if results == nil {
            NSLog("[%@ %@] fetch error: %@", self.description(), __FUNCTION__, error!)
        }
        return results?.first as? Smilie
    }

}
