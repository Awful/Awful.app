//  CollectionTypeDelta.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension CollectionType where Index: Hashable, Generator.Element: Equatable {
    
    /**
    Returns the difference between `self` and another collection, expressed as a series of deletions, insertions, and moves.
    
    The returned `Delta` is particularly useful for updating a `UICollectionView` or `UITableView`.
    */
    func delta(other: Self) -> Delta<Index> {
        var unchanged: Set<Index> = []
        for var i = startIndex; i != endIndex && i != other.endIndex; i = i.successor() {
            if self[i] == other[i] {
                unchanged.insert(i)
            }
        }
        
        var insertions: [Index] = []
        var moves: [(from: Index, to: Index)] = []
        for var i = other.startIndex; i != other.endIndex; i = i.successor() {
            if unchanged.contains(i) { continue }
            
            let otherValue = other[i]
            if let oldIndex = indexOf(otherValue) {
                moves.append((from: oldIndex, to: i))
            } else {
                insertions.append(i)
            }
        }
        
        var deletions: [Index] = []
        for var i = startIndex; i != endIndex; i = i.successor() {
            if unchanged.contains(i) { continue }
            
            let value = self[i]
            if !other.contains(value) {
                deletions.append(i)
            }
        }
        
        return Delta(deletions: deletions, insertions: insertions, moves: moves)
    }
}

/// See documentation for `CollectionType.delta` for usage suggestions.
struct Delta<Index> {
    let deletions: [Index]
    let insertions: [Index]
    let moves: [(from: Index, to: Index)]
    
    /// `true` if and only if the compared collections were identical.
    var isEmpty: Bool {
        return deletions.isEmpty && insertions.isEmpty && moves.isEmpty
    }
    
    // Private initializer suggests this struct is not generally useful except as returned by `CollectionType.delta()`.
    private init(deletions: [Index], insertions: [Index], moves: [(from: Index, to: Index)]) {
        self.deletions = deletions
        self.insertions = insertions
        self.moves = moves
    }
}
