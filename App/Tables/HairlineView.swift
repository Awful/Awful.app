//  HairlineView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

@IBDesignable
final class HairlineView: UIView {
    var thickness: CGFloat {
        return 1 / max(traitCollection.displayScale, 1)
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection == nil || previousTraitCollection?.displayScale != traitCollection.displayScale {
            invalidateIntrinsicContentSize()
        }
    }

    override func intrinsicContentSize() -> CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: thickness)
    }
}
