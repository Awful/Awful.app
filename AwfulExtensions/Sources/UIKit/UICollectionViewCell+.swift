//  UICollectionViewCell+.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UICollectionViewCell {
    /// Gets/sets the background color of the selectedBackgroundView (inserting one if necessary).
    var selectedBackgroundColor: UIColor? {
        get {
            selectedBackgroundView?.backgroundColor
        }
        set {
            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
            selectedBackgroundView?.backgroundColor = newValue
        }
    }
}
