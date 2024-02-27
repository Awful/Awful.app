//  Comparable+.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// MARK: Clamped

public extension Comparable {

    /**
     Returns `self` if it is contained within `range`, otherwise returns `range`'s lower or upper bound (whichever is closer to `self`).
     */
    @inlinable func clamped(to range: ClosedRange<Self>) -> Self {
        self
            .clamped(to: range.lowerBound...)
            .clamped(to: ...range.upperBound)
    }

    /**
     Returns `self` if it is contained within `range`, otherwise returns `range`'s lower bound.
     */
    @inlinable func clamped(to range: PartialRangeFrom<Self>) -> Self {
        range.contains(self) ? self : range.lowerBound
    }

    /**
     Returns `self` if it is contained within `range`, otherwise returns `range`'s upper bound.
     */
    @inlinable func clamped(to range: PartialRangeThrough<Self>) -> Self {
        range.contains(self) ? self : range.upperBound
    }
}
