//  Task+sleepUnits.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension Task where Success == Never, Failure == Never {
    /// Suspends the current task for the given duration.
    static func sleep(for duration: Measurement<UnitDuration>) async throws {
        try await sleep(nanoseconds: UInt64(duration.converted(to: .nanoseconds).value))
    }

    /// Suspends the current task for the given duration.
    static func sleep(timeInterval: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(timeInterval * TimeInterval(NSEC_PER_SEC)))
    }
}
