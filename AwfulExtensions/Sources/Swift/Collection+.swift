//  Collection+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// Thanks to https://gist.github.com/milseman/f9b5528345db3a36bbdd138af52c5cda

/**
 `Foundation.Scanner`-like methods on self-slicing collections (e.g. `Data`, `Substring`).

 Usage:

 ```swift
 // `String` doesn't meet requirements, but `Substring` does.
 var scanner = someString[...]
 scanner.skip(while: \.isWhitespace)
 guard scanner.scan("expected prefix") else { return false }
 ```
 */
public extension Collection where SubSequence == Self {

    /**
     Remove `prefix` from the start of the collection if it is a prefix of the collection.

     - Returns: `true` if `prefix` was a prefix of the collection (and so the collection was modified).
     */
    mutating func scan<Prefix>(
        _ prefix: Prefix
    ) -> Bool where Element: Equatable, Prefix: Sequence, Prefix.Element == Element {
        var indices = self.indices.makeIterator()
        for p in prefix {
            guard let i = indices.next(),
                  self[i] == p
            else { return false }
        }
        if let i = indices.next() {
            self = self[i...]
        } else {
            self = self[endIndex...]
        }
        return true
    }

    mutating func scan(until predicate: (Element) -> Bool) -> Self? {
        let i = firstIndex(where: predicate) ?? endIndex
        let prefix = self[..<i]
        self = self[i...]
        if prefix.isEmpty {
            return nil
        }
        return prefix
    }

    mutating func scan(while predicate: (Element) -> Bool) -> Self? {
        return scan(until: { !predicate($0) })
    }
}
