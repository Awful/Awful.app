//  CoreExtensions.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Array {
    /// Returns the first element for which the predicate returns true.
    func first(predicate: Element -> Bool) -> Element? {
        for item in self {
            if predicate(item) {
                return item
            }
        }
        return nil
    }
    
    /// Same as reduce() but with the first element used as the initial accumulated value.
    func reduce(combine: (Element, Element) -> Element) -> Element? {
        if let initial = first {
            return Swift.reduce(dropFirst(self), initial, combine)
        } else {
            return nil
        }
    }
}

/// Returns true if any elements in sequence pass the predicate.
func any<S: SequenceType, T where T == S.Generator.Element>(sequence: S, predicate: T -> Bool) -> Bool {
    return first(sequence, predicate) != nil
}

/// Returns the first element in sequence that passes the predicate.
func first<S: SequenceType, T where T == S.Generator.Element>(sequence: S, predicate: T -> Bool) -> T? {
    for element in sequence {
        if predicate(element) {
            return element
        }
    }
    return nil
}

extension Int {
    func clamp<T: IntervalType where T.Bound == Int>(interval: T) -> Int {
        if self < interval.start {
            return interval.start
        } else if self > interval.end {
            return interval.end
        } else {
            return self
        }
    }
}
