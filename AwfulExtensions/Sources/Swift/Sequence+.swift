//  Sequence+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// MARK: Identical object search

public extension Sequence where Element: AnyObject {

    /**
     Returns a Boolean value indicating whether the sequence contains an element that is pointer-identical to `object`.

     This is faster than an equality check for e.g. `NSManagedObject`s in the same context, because the context guarantees no more than one instance per represented object.
     */
    func containsObjectIdentical(to object: AnyObject) -> Bool {
        return contains { $0 === object }
    }
}

// MARK: Reduce with first element

public extension Sequence {

    /// Same as `reduce(_:_:)` but with the first element used as the initial result value. Returns `nil` when the sequence is empty.
    func reduce(_ combine: (Element, Element) throws -> Element) rethrows -> Element? {
        var iterator = makeIterator()

        guard var result = iterator.next() else { return nil }

        while let next = iterator.next() {
            result = try combine(result, next)
        }

        return result
    }
}
