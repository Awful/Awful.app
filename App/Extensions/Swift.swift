//  Swift.swift
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
            return self.dropFirst().reduce(initial, combine: combine)
        } else {
            return nil
        }
    }
}

func any<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: T -> Bool) -> Bool {
    return first(sequence, includeElement: includeElement) != nil
}

func first<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: T -> Bool) -> T? {
    for element in sequence {
        if includeElement(element) {
            return element
        }
    }
    return nil
}
