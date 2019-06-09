//  ManagedObjectObserver.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

/// Calls a block whenever a particular managed object is deleted, invalidated, refreshed, or updated.
final class ManagedObjectObserver {
    
    private let didChange: (Change) -> Void
    private var token: NSObjectProtocol?

    enum Change {

        /// The managed object was deleted or invalidated.
        case delete

        /// The managed object was refreshed or updated.
        case update
    }

    init?(object: NSManagedObject, didChange: @escaping (Change) -> Void) {
        guard let context = object.managedObjectContext else { return nil }

        self.didChange = didChange

        token = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: nil) { [unowned self] notification in
            let notification = ContextObjectsDidChangeNotification(notification)
            guard let change = Change(object: object, notification: notification) else { return }
            self.didChange(change)
        }
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

private extension ManagedObjectObserver.Change {
    init?(object: NSManagedObject, notification: ContextObjectsDidChangeNotification) {
        if notification.didInvalidateAllObjects
            || notification.invalidatedObjects.containsObjectIdentical(to: object)
            || notification.deletedObjects.containsObjectIdentical(to: object)
        {
            self = .delete
        }
        else if notification.refreshedObjects.containsObjectIdentical(to: object)
            || notification.updatedObjects.containsObjectIdentical(to: object)
        {
            self = .update
        }
        else {
            return nil
        }
    }
}
