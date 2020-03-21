//  DepthFirstSequenceTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulScraping
import XCTest

class DepthFirstSequenceTests: XCTestCase {

    struct Node {
        let id: String
        var children: [Node]
    }

    private func iterate(_ root: Node) -> [(node: Node, depth: Int)] {
        Array(DepthFirstSequence(root: root, children: \.children))
    }

    func testOne() {
        let root = Node(id: "root", children: [])
        let result = iterate(root)
        XCTAssertEqual(result.map { $0.node.id }, ["root"])
        XCTAssertEqual(result.map { $0.depth }, [0])
    }

    func testUnbalancedBinaryLeft() {
        let root = Node(id: "root", children: [
            Node(id: "subleft", children: [
                Node(id: "subsubleft", children: [
                    Node(id: "subsubsubleft", children: []),
                ]),
            ]),
            Node(id: "subright", children: []),
        ])
        let result = iterate(root)
        XCTAssertEqual(result.map { $0.node.id }, ["root", "subleft", "subsubleft", "subsubsubleft", "subright"])
        XCTAssertEqual(result.map { $0.depth }, [0, 1, 2, 3, 1])
    }
}
