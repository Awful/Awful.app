//  Swift.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Array {
    /// Returns the first element for which the predicate returns true.
    func first(_ predicate: (Element) -> Bool) -> Element? {
        for item in self {
            if predicate(item) {
                return item
            }
        }
        return nil
    }
    
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
    func all(_ includeElement: (Iterator.Element) -> Bool) -> Bool {
        for element in self where !includeElement(element) {
            return false
        }
        return true
    }
    
    func any(_ includeElement: (Iterator.Element) -> Bool) -> Bool {
        for element in self where includeElement(element) {
            return true
        }
        return false
    }
}

func any<S: Sequence, T>(_ sequence: S, includeElement: (T) -> Bool) -> Bool where T == S.Iterator.Element {
    return first(sequence, includeElement: includeElement) != nil
}

func first<S: Sequence, T>(_ sequence: S, includeElement: (T) -> Bool) -> T? where T == S.Iterator.Element {
    for element in sequence {
        if includeElement(element) {
            return element
        }
    }
    return nil
}
