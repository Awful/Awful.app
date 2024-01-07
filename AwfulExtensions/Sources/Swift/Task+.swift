//  Task+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine
import Foundation

// MARK: AnyCancellable

public extension Task {
    /// Returns an AnyCancellable that cancels this task.
    func makeCancellable() -> AnyCancellable {
        AnyCancellable(cancel)
    }

    /// Stores an AnyCancellable for this task in the collection.
    func store<C>(
        in collection: inout C
    ) where C: RangeReplaceableCollection, C.Element == AnyCancellable {
        collection.append(makeCancellable())
    }

    /// Stores an AnyCancellable for this task in the set.
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(makeCancellable())
    }
}

// MARK: Sleep with useful units

// Swift.Duration is iOS 16+, so we'll use Foundation time interval units until then.

public extension Task where Success == Never, Failure == Never {
    /// Suspends the current task for the given duration.
    static func sleep(for duration: Measurement<UnitDuration>) async throws {
        try await sleep(nanoseconds: UInt64(duration.converted(to: .nanoseconds).value))
    }

    /// Suspends the current task for the given duration.
    static func sleep(timeInterval: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(timeInterval * TimeInterval(NSEC_PER_SEC)))
    }
}
