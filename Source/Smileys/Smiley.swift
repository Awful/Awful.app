//  Smiley.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData

public class Smiley: NSManagedObject {

    @NSManaged public var imageData: NSData?
    @NSManaged public var imageURL: NSString?
    @NSManaged public var section: String?
    @NSManaged public var summary: String?
    @NSManaged public var text: String
    
    public var metadata: SmileyMetadata {
        get {
            let fetchedMetadata = valueForKey("fetchedMetadata") as [SmileyMetadata]
            if !fetchedMetadata.isEmpty {
                return fetchedMetadata[0]
            } else if !text.isEmpty {
                let metadata = NSEntityDescription.insertNewObjectForEntityForName("SmileyMetadata", inManagedObjectContext: managedObjectContext) as SmileyMetadata
                metadata.smileyText = text
                return metadata
            } else {
                fatalError("smiley needs text before you can access its metadata")
            }
        }
    }
    
    public convenience init(managedObjectContext context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Smiley", inManagedObjectContext: context)
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
    }

}
