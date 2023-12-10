//  Task+AnyCancellable.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine

extension Task {
    /// Returns an AnyCancellable that cancels this task.
    func makeCancellable() -> AnyCancellable {
        AnyCancellable(cancel)
    }

    /// Stores an AnyCancellable for this task in the collection.
    func store<C>(
        in collection: inout C
    ) where C: RangeReplaceableCollection, C.Element == AnyCancellable {
        collection.append(makeCancellable())
    }

    /// Stores an AnyCancellable for this task in the set.
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(makeCancellable())
    }
}
