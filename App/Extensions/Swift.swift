//  Swift.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Numeric where Self: Comparable {
    
    /// Returns `self` if it's within `range`, otherwise returns the bound of `range` nearest to `self`.
    func clamp(_ range: ClosedRange<Self>) -> Self {
        if self < range.lowerBound {
            return range.lowerBound
        } else if self > range.upperBound {
            return range.upperBound
        } else {
            return self
        }
    }
}

extension Sequence {
    
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
