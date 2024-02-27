//  UIView+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// MARK: - Adding with constraints

public extension UIView {
    /**
     Creates and activates edge constraints between the view and the given descendant.

     Returns the constraints for further modification or storage.
     */
    @discardableResult
    func constrain(
        to view: UIView,
        edges: UIRectEdge,
        insets: UIEdgeInsets = .zero
    ) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        if edges.contains(.top) {
            constraints.append(topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top))
        }
        if edges.contains(.bottom) {
            constraints.append(view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom))
        }
        if edges.contains(.left) {
            constraints.append(leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left))
        }
        if edges.contains(.right) {
            constraints.append(view.rightAnchor.constraint(equalTo: rightAnchor, constant: insets.right))
        }
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    /// Adds a subview and immediately activates constraints for the given edges.
    func addSubview(
        _ subview: UIView,
        constrainEdges edges: UIRectEdge,
        insets: UIEdgeInsets = .zero
    ) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        subview.constrain(to: self, edges: edges, insets: insets)
    }
}

// MARK: - Fitting size

public extension UIView {
    /// Returns the view's fitting height assuming its width is `width`.
    func layoutFittingCompressedHeight(targetWidth width: CGFloat) -> CGFloat {
        systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}
