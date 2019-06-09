//  UIView+SafeAreaFrame.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIView {

    /**
     Returns the safe area in the view's coordinate system.

     Before iOS 11, simply returns the view's bounds.
     */
    var safeAreaFrame: CGRect {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.layoutFrame
        } else {
            return bounds
        }
    }
}
