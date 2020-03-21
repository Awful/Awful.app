//  UpsertBatch.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

/**
 Fetches existing objects in bulk from a context and lazily inserts nonexistant objects.
 */
class UpsertBatch<T: NSManagedObject & Managed> {

    private let context: NSManagedObjectContext
    private let idKeyPath: WritableKeyPath<T, String>
    private var objects: [String: T]

    init(
        in context: NSManagedObjectContext,
        identifiedBy keyPath: WritableKeyPath<T, String>,
        identifiers: [String]
    ) {
        self.context = context
        idKeyPath = keyPath

        objects = .init(uniqueKeysWithValues:
            T.fetch(in: context) {
                $0.predicate = .init("\(keyPath) IN \(identifiers)")
                $0.returnsObjectsAsFaults = false
            }.map { ($0[keyPath: keyPath], $0) }
        )
    }

    subscript(_ id: String) -> T {
        if let object = objects[id] {
            return object
        } else {
            var object = T(context: context)
            object[keyPath: idKeyPath] = id
            objects[id] = object
            return object
        }
    }
}
