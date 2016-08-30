//  Swift.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Array {
    /// Returns the first element for which the predicate returns true.
    func first(predicate: (Element) -> Bool) -> Element? {
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
            return self.dropFirst().reduce(initial, combine)
        } else {
            return nil
        }
    }
}

extension Int {
    func clamp<T: IntervalType>(interval: T) -> Int where T.Bound == Int {
        if self < interval.start {
            return interval.start
        } else if self > interval.end {
            return interval.end
        } else {
            return self
        }
    }
}

extension Sequence {
    func all(includeElement: Generator.Element -> Bool) -> Bool {
        for element in self where !includeElement(element) {
            return false
        }
        return true
    }
    
    func any(includeElement: Generator.Element -> Bool) -> Bool {
        for element in self where includeElement(element) {
            return true
        }
        return false
    }
}

func any<S: Sequence, T>(sequence: S, includeElement: (T) -> Bool) -> Bool where T == S.Iterator.Element {
    return first(sequence: sequence, includeElement: includeElement) != nil
}

func first<S: Sequence, T>(sequence: S, includeElement: (T) -> Bool) -> T? where T == S.Iterator.Element {
    for element in sequence {
        if includeElement(element) {
            return element
        }
    }
    return nil
}
