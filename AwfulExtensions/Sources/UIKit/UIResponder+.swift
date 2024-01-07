//  UIResponder+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// MARK: Responder chain sequence

public extension UIResponder {

    /// Returns the responders in the chain, starting with the responder.
    var responderChain: some Sequence<UIResponder> {
        sequence(first: self, next: \.next)
    }

    /// Returns the first view controller in the responder chain.
    var nearestViewController: UIViewController? {
        responderChain.first { $0 is UIViewController } as! UIViewController?
    }
}
