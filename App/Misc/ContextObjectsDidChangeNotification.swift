//
//  ContextObjectsDidChangeNotification.swift
//  Awful
//
//  Created by Nolan Waite on 2017-08-30.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import CoreData
import Foundation

/// Lil wrapper around an `NSManagedObjectContextObjectsDidChangeNotification` and its user info keys.
struct ContextObjectsDidChangeNotification {
    private let notification: Notification

    init(_ notification: Notification) {
        assert(notification.name == .NSManagedObjectContextObjectsDidChange)
        self.notification = notification
    }

    private func objects(forKey key: String) -> Set<NSManagedObject> {
        return notification.userInfo?[key] as? Set<NSManagedObject> ?? []
    }

    var deletedObjects: Set<NSManagedObject> {
        return objects(forKey: NSDeletedObjectsKey)
    }

    var didInvalidateAllObjects: Bool {
        return notification.userInfo?[NSInvalidatedAllObjectsKey] != nil
    }

    var insertedObjects: Set<NSManagedObject> {
        return objects(forKey: NSInsertedObjectsKey)
    }

    var invalidatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSInvalidatedObjectsKey)
    }

    var refreshedObjects: Set<NSManagedObject> {
        return objects(forKey: NSRefreshedObjectsKey)
    }

    var updatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSUpdatedObjectsKey)
    }
}
