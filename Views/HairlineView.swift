//  HairlineView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A view whose intrinsic height is one device pixel. Set its background color and you've got a hairline.
@IBDesignable public final class HairlineView: UIView {
    public var thickness: CGFloat {
        return 1 / max(traitCollection.displayScale, 1)
    }
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection == nil || previousTraitCollection?.displayScale != traitCollection.displayScale {
            invalidateIntrinsicContentSize()
        }
    }

    public override func intrinsicContentSize() -> CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: thickness)
    }
}
