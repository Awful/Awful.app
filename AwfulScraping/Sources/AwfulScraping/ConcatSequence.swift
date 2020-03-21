//  ConcatSequence.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Concatenates a sequence of sequences, providing access to the elements of each sequence in turn.
struct ConcatSequence<S: Sequence>: Sequence
    where S.Element: Sequence
{
    private let sequences: S

    init(_ sequences: S) { self.sequences = sequences }

    func makeIterator() -> Iterator {
        Iterator(sequences.makeIterator())
    }

    struct Iterator: IteratorProtocol {
        private var cur: S.Element.Iterator?
        private var it: S.Iterator

        fileprivate init(_ iterators: S.Iterator) {
            it = iterators
        }

        mutating func next() -> S.Element.Element? {
            if let el = cur?.next() {
                return el
            } else {
                cur = it.next()?.makeIterator()
                return cur?.next()
            }
        }
    }
}
