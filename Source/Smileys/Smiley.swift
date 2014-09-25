//  Smiley.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData

public class Smiley: NSManagedObject {

    @NSManaged public var imageData: NSData?
    @NSManaged public var section: String?
    @NSManaged public var summary: String?
    @NSManaged public var text: String
    
    public var imageURL: NSURL? {
        get {
            if let URLString = primitiveImageURL {
                return NSURL(string: URLString)
            } else {
                return nil
            }
        }
        set {
            willChangeValueForKey("imageURL")
            if let URL = newValue {
                primitiveImageURL = URL.absoluteString
            } else {
                primitiveImageURL = nil
            }
            didChangeValueForKey("imageURL")
        }
    }
    @NSManaged private var primitiveImageURL: String?
    
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

}
