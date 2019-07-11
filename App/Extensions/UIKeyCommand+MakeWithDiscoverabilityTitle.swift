//  UIKeyCommand+MakeWithDiscoverabilityTitle.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIKeyCommand {

    /**
     Returns a key command initialized with the given parameters, and with the discoverability title set.

     A convenience initailzier with these exact parameters was deprecated in iOS 13 and so is unavailable in UIKit for Mac. A more thorough convenience initializer with parameters in a different order was introduced in iOS 13 but is unavailable on older iOS versions. This factory method bridges the gap.
     */
    static func make(input: String, modifierFlags: UIKeyModifierFlags = [], action: Selector, discoverabilityTitle: String) -> UIKeyCommand {
        let command = UIKeyCommand(input: input, modifierFlags: modifierFlags, action: action)
        command.discoverabilityTitle = discoverabilityTitle
        return command
    }
}
