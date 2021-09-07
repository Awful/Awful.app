//  UIAccessibility+Catalyst.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIAccessibility {
    /**
     Posted by UIKit when VoiceOver starts or stops.

     Returns `UIAccessibility.voiceOverStatusDidChangeNotification` on iOS 11+ and Catalyst, falling back to `UIAccessibilityVoiceOverStatusChanged` on iOS 10-.
     */
    static var voiceOverStatusChangedNotification: Foundation.Notification.Name {
        if #available(iOS 11, *) {
            return voiceOverStatusDidChangeNotification
        } else {
            return .init(UIAccessibilityVoiceOverStatusChanged)
        }
    }
}
