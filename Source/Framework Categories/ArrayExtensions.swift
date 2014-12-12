//  ArrayExtensions.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Array {
    func reduce(combine: (Element, Element) -> Element) -> Element? {
        if let initial = first {
            return Swift.reduce(dropFirst(self), initial, combine)
        } else {
            return nil
        }
    }
}
