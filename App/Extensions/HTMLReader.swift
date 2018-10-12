//  HTMLReader.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

extension HTMLNode {
    
    /**
     Replaces one child node with one or more new nodes.
     
     If the outgoing child node is not found, nothing happens.
     */
    func replace(child outgoing: HTMLNode, with incoming: HTMLNode...) {
        let children = mutableChildren
        let i = children.index(of: outgoing)
        guard i != NSNotFound else { return }
        children.removeObject(at: i)
        children.insert(incoming, at: IndexSet(integersIn: i..<(i + incoming.count)))
    }
    
    /**
     Replaces the node with `newParent`, then becomes a child of `newParent`.
     */
    func wrap(in newParent: HTMLNode) {
        parent?.replace(child: self, with: newParent)
        newParent.addChild(self)
    }
}

extension HTMLTextNode {

    /**
     Splits the text node in two or three, isolating the text at `range` in its own node, and replaces the text node with the newly-created text nodes.
     
     If the range covers the entire text node, it is returned unchanged.
     
     If the text node has no parent, returned text nodes will also have no parent.
     
     It is a programmer error if `range` exceeds the bounds of the text node's data.
     */
    func split(_ range: Range<String.Index>) -> SplitRangeResult {
        precondition(range.clamped(to: data.startIndex..<data.endIndex) == range, "range cannot exceed text node's contents")
        
        let isAnchoredAtBeginning = range.lowerBound == data.startIndex
        let isAnchoredAtEnd = range.upperBound == data.endIndex
        if isAnchoredAtBeginning, isAnchoredAtEnd {
            return .entireNode(self)
        } else if isAnchoredAtBeginning {
            let match = HTMLTextNode(data: String(data[range]))
            let remainder = HTMLTextNode(data: String(data[range.upperBound...]))
            parent?.replace(child: self, with: match, remainder)
            return .anchoredAtBeginning(match: match, remainder: remainder)
        } else if isAnchoredAtEnd {
            let remainder = HTMLTextNode(data: String(data[..<range.lowerBound]))
            let match = HTMLTextNode(data: String(data[range]))
            parent?.replace(child: self, with: remainder, match)
            return .anchoredAtEnd(remainder: remainder, match: match)
        } else {
            let beginning = HTMLTextNode(data: String(data[..<range.lowerBound]))
            let match = HTMLTextNode(data: String(data[range]))
            let end = HTMLTextNode(data: String(data[range.upperBound...]))
            parent?.replace(child: self, with: beginning, match, end)
            return .middle(beginning: beginning, match: match, end: end)
        }
    }
    
    /// - Seealso: `HTMLTextNode.split(range:)`.
    enum SplitRangeResult {
        
        /// The range covered the entire text node, so it is returned unchanged.
        case entireNode(HTMLTextNode)
        
        /// The range included the beginning of the text node, so it was split in two with the remainder following the range.
        case anchoredAtBeginning(match: HTMLTextNode, remainder: HTMLTextNode)
        
        /// The range included the end of the text node, so it was split in two with the remainder preceding the range.
        case anchoredAtEnd(remainder: HTMLTextNode, match: HTMLTextNode)
        
        /// The range was in the middle of the text node, so it was split in three, with some remainder on either side of the range.
        case middle(beginning: HTMLTextNode, match: HTMLTextNode, end: HTMLTextNode)
    }
}
