//  NSManagedObject+OwnContext.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

/**
 Lets any managed object run work on its own context's queue via `onOwnContext(_:)`.

 `NSManagedObjectContext.perform` takes a `@Sendable` closure, and `NSManagedObject` is deliberately not `Sendable`, so capturing an object in that closure warns even when the closure runs on the only queue that is allowed to touch the object. This helper states that fact once: `body` receives the object *on its context's queue*, which is exactly Core Data's threading contract, so the capture is safe. Do not use the object outside `body`.
 */
protocol OwnContextPerforming: NSManagedObject {}

extension OwnContextPerforming {

    /**
     Runs `body` on this object's context queue, handing it the object and that context.

     Traps if the object has no context (it was deleted or never inserted), matching the `managedObjectContext!` force-unwraps this replaces.
     */
    func onOwnContext<T>(
        _ body: @escaping @Sendable (Self, NSManagedObjectContext) throws -> T
    ) async rethrows -> T {
        guard let context = managedObjectContext else {
            preconditionFailure("\(Self.self) has no managed object context")
        }
        let object = UncheckedSendable(self)
        return try await context.perform {
            try body(object.value, context)
        }
    }

    /// Same as `onOwnContext(_:)` for work that only needs the object, e.g. `thread.onOwnContext { $0.threadID }`.
    func onOwnContext<T>(
        _ body: @escaping @Sendable (Self) throws -> T
    ) async rethrows -> T {
        try await onOwnContext { object, _ in try body(object) }
    }
}

extension NSManagedObject: OwnContextPerforming {}

/// Asserts that `Value` is safe to send. Only for the `onOwnContext(_:)` handoff above, where the value is only ever used on its own context's queue.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
