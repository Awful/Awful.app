//  Managed.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

// Core Data helpers for Swift, largely copied from https://github.com/objcio/core-data (buy the book!)

public protocol Managed: NSFetchRequestResult {
    static var entityName: String { get }
}

extension Managed where Self: NSManagedObject {

    public static func insert(
        into context: NSManagedObjectContext
    ) -> Self {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Self
    }

    public static func findOrCreate(
        in context: NSManagedObjectContext,
        matching predicate: NSPredicate,
        configure: (Self) -> Void
    ) -> Self {
        if let object = findOrFetch(in: context, matching: predicate) {
            return object
        } else {
            let newObject = Self.insert(into: context)
            configure(newObject)
            return newObject
        }
    }

    public static func findOrFetch(
        in context: NSManagedObjectContext,
        matching predicate: NSPredicate
    ) -> Self? {
        if let object = materializedObject(in: context, matching: predicate) {
            return object
        } else {
            return fetch(in: context) {
                $0.predicate = predicate
                $0.returnsObjectsAsFaults = false
                $0.fetchLimit = 1
            }.first
        }
    }

    public static func materializedObject(
        in context: NSManagedObjectContext,
        matching predicate: NSPredicate
    ) -> Self? {
        context.registeredObjects.lazy
            .filter { !$0.isFault }
            .compactMap { $0 as? Self }
            .first { predicate.evaluate(with: $0) }
    }

    public static func fetch(
        in context: NSManagedObjectContext,
        configure: (NSFetchRequest<Self>) -> Void
    ) -> [Self] {
        let request = makeFetchRequest()
        configure(request)
        return try! context.fetch(request)
    }

    public static func count(
        in context: NSManagedObjectContext,
        configure: (NSFetchRequest<Self>) -> Void = { _ in }
    ) -> Int {
        let request = makeFetchRequest()
        configure(request)
        return try! context.count(for: request)
    }

    public static func makeFetchRequest() -> NSFetchRequest<Self> {
        .init(entityName: entityName)
    }
}
