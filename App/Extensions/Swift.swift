//  Swift.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Array {
    /// Same as reduce() but with the first element used as the initial accumulated value.
    func reduce(_ combine: (Element, Element) -> Element) -> Element? {
        if let initial = first {
            return self.dropFirst().reduce(initial, combine)
        } else {
            return nil
        }
    }
}

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
