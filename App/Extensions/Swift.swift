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

extension Int {
    func clamp(_ range: ClosedRange<Int>) -> Int {
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

    /**
     Returns `true` if `predicate` returns `true` for any element in the sequence.

     This method stops as soon as `predicate` returns `true`.
     */
    func any(where predicate: (_ element: Element) -> Bool) -> Bool {
        for element in self where predicate(element) {
            return true
        }
        return false
    }
}
