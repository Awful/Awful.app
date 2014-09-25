//  SmileyMetadata.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData

public class SmileyMetadata: NSManagedObject {

    @NSManaged public var lastUseDate: NSDate?
    @NSManaged public internal(set) var smileyText: String

}
