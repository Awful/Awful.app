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

    /// - Parameter mergingDuplicates: Picks the one object to stand for an identifier that several
    ///   fetched objects share. Nothing in the model enforces uniqueness, so duplicates do turn up
    ///   in the store, and a batch that assumed otherwise would trap. The default keeps the first
    ///   object fetched; pass something smarter (`merge(_:)` for users, say) to fold the others in.
    init(
        in context: NSManagedObjectContext,
        identifiedBy keyPath: WritableKeyPath<T, String>,
        identifiers: [String],
        mergingDuplicates merge: ([T]) -> T = { $0[0] }
    ) {
        self.context = context
        idKeyPath = keyPath

        let fetched = T.fetch(in: context) {
            $0.predicate = .init("\(keyPath) IN \(identifiers)")
            $0.returnsObjectsAsFaults = false
        }
        objects = Dictionary(grouping: fetched, by: { $0[keyPath: keyPath] }).mapValues(merge)
    }

    subscript(_ id: String) -> T {
        if let object = objects[id] {
            return object
        } else {
            var object = T.insert(into: context)
            object[keyPath: idKeyPath] = id
            objects[id] = object
            return object
        }
    }
}
