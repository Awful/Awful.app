//  SmilieMetadata.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData

@objc(SmilieMetadata)
public class SmilieMetadata: NSManagedObject {

    @NSManaged public var lastUseDate: NSDate?
    @NSManaged public internal(set) var smilieText: SmiliePrimaryKey

}
