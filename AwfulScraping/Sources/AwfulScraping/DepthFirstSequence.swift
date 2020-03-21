//  DepthFirstSequence.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/**
 Provides access to nodes of a tree-like structure in depth-first order.

 Elements are a tuple of: the value at each node, and the depth of that node relative to the passed-in root. (The root is at depth 0.)
 */
struct DepthFirstSequence<T>: Sequence {
    private let root: T
    private let children: KeyPath<T, [T]>
    
    /**
     - Parameter root: The root node of a (sub)tree.
     - Parameter children: An accessor for a node's children.
     */
    init(root: T, children: KeyPath<T, [T]>) {
        self.root = root
        self.children = children
    }

    func makeIterator() -> Iterator {
        Iterator(root: root, children: children)
    }

    struct Iterator: IteratorProtocol {
        private let children: KeyPath<T, [T]>
        private var nodes: [(node: T, index: Int)]

        fileprivate init(root: T, children: KeyPath<T, [T]>) {
            self.children = children
            nodes = [(root, 0)]
        }

        mutating func next() -> (node: T, depth: Int)? {
            guard let cur = nodes.last?.node else { return nil }
            let depth = nodes.count - 1
            while let (node, i) = nodes.last, i >= node[keyPath: children].count {
                nodes.removeLast()
            }
            if let (node, i) = nodes.last {
                nodes[nodes.count - 1].index = i + 1
                nodes.append((node[keyPath: children][i], 0))
            }
            return (cur, depth)
        }
    }
}
