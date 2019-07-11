//  UIScrollView+ScrollIndicatorInsetBottom.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIScrollView {

    /**
     Gets and sets the vertical scroll indicator bottom inset.

     `scrollIndicatorInsets` is deprecated in iOS 13 and thus unavaialble in UIKit for Mac. `verticalScrollIndicatorInsets` was introduced in iOS 11.1. This method bridges the gap.
     */
    var scrollIndicatorInsetBottom: CGFloat {
        get {
            #if targetEnvironment(UIKitForMac)
            return verticalScrollIndicatorInsets.bottom
            #else
            return scrollIndicatorInsets.bottom
            #endif
        }
        set {
            #if targetEnvironment(UIKitForMac)
            verticalScrollIndicatorInsets.bottom = newValue
            #else
            scrollIndicatorInsets.bottom = newValue
            #endif
        }
    }
}
