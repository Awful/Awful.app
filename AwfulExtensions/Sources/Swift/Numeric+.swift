//  Numeric+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// MARK: Clamp

public extension Numeric where Self: Comparable {

    /// Returns `self` if it's within `range`, otherwise returns the bound of `range` nearest to `self`.
    func clamp(_ range: ClosedRange<Self>) -> Self {
        if self < range.lowerBound {
            range.lowerBound
        } else if self > range.upperBound {
            range.upperBound
        } else {
            self
        }
    }
}
