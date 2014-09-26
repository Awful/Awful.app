//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation
import Smileys

func inMemoryDataStack() -> NSManagedObjectContext {
    let modelURL = NSBundle(forClass: Smiley.self).URLForResource("Smileys", withExtension: "momd")
    let model = NSManagedObjectModel(contentsOfURL: modelURL!)
    let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    var error: NSError? = nil
    let store = storeCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
    assert(store != nil, "error adding in-memory store: \(error)")
    let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    context.persistentStoreCoordinator = storeCoordinator
    return context
}

class WebArchive {
    private let plist: NSDictionary
    
    required init(URL: NSURL) {
        let stream = NSInputStream(URL: URL)
        stream.open()
        var error: NSError?
        let plist = NSPropertyListSerialization.propertyListWithStream(stream, options: 0, format: nil, error: &error) as NSDictionary!
        assert(plist != nil, "error loading webarchive at \(URL): \(error)")
        self.plist = plist
    }
    
    var mainFrameHTML: String {
        get {
            let mainResource = plist["WebMainResource"] as NSDictionary
            let data = mainResource["WebResourceData"] as NSData
            return NSString(data: data, encoding: NSUTF8StringEncoding)
        }
    }
    
    func dataForSubresourceWithURL(URL: String) -> NSData? {
        let subresources = plist["WebSubresources"] as [[String:AnyObject]]
        for resource in subresources {
            let thisURL = resource["WebResourceURL"] as NSString!
            if thisURL == URL {
                return resource["WebResourceData"] as NSData!
            }
        }
        return nil
    }
}

extension WebArchive {
    class func loadFromFixture() -> Self {
        let URL = NSBundle(forClass: ScrapingTests.self).URLForResource("showsmileys", withExtension: "webarchive")
        return self(URL: URL!)
    }
}
