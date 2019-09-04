//  UIActivityIndicatorView+MakeLarge.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIActivityIndicatorView {

    /**
     Returns an activity indicator view of the large style.

     The style name changed in iOS 13 and the old one is unavailable in UIKit for Mac. This method deals with it.
     */
    class func makeLarge() -> Self {
        #if targetEnvironment(macCatalyst)
        return self.init(style: .large)
        #else
        return self.init(style: .whiteLarge)
        #endif
    }
}
