//  ManagedObjectCountObserver.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

/// Calls a block whenever the count of matching managed objects changes.
final class ManagedObjectCountObserver {
    private let context: NSManagedObjectContext
    private let didChange: (_ count: Int) -> Void
    private let fetchRequest: NSFetchRequest<NSManagedObject>
    private var token: NSObjectProtocol?

    init(context: NSManagedObjectContext, entityName: String, predicate: NSPredicate, didChange: @escaping (_ count: Int) -> Void) {
        self.context = context
        self.didChange = didChange

        fetchRequest = NSFetchRequest(entityName: entityName)
        fetchRequest.predicate = predicate

        updateCount()

        token = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: .main) { [unowned self] notification in

            let notification = ContextObjectsDidChangeNotification(notification)

            func isRelevant(_ object: NSManagedObject) -> Bool {
                return object.entity.name == entityName
            }

            guard notification.didInvalidateAllObjects
                || notification.deletedObjects.contains(where: isRelevant)
                || notification.insertedObjects.contains(where: isRelevant)
                || notification.invalidatedObjects.contains(where: isRelevant)
                || notification.refreshedObjects.contains(where: isRelevant)
                || notification.updatedObjects.contains(where: isRelevant)
                else { return }

            self.updateCount()
        }
    }

    private(set) var count: Int = 0 {
        didSet {
            if oldValue != count {
                didChange(count)
            }
        }
    }

    private func updateCount() {
        do {
            count = try context.count(for: fetchRequest)
        }
        catch {
            fatalError("could not count: \(error)")
        }
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
