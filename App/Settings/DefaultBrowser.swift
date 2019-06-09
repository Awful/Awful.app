//  DefaultBrowser.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

enum DefaultBrowser: String, CaseIterable {
    case awful = "Awful"
    case safari = "Safari"
    case chrome = "Chrome"
    case firefox = "Firefox"
}

extension DefaultBrowser {
    var isInstalled: Bool {
        switch self {
        case .awful, .safari:
            return true
        case .chrome:
            return UIApplication.shared.canOpenURL(URL(string: "googlechrome://")!)
        case .firefox:
            return UIApplication.shared.canOpenURL(URL(string: "firefox://")!)
        }
    }
    
    fileprivate static var fallback: DefaultBrowser = .safari
    
    static var installedBrowsers: [DefaultBrowser] {
        return allCases.filter { $0.isInstalled }
    }
}

extension UserDefaults {
    
    /**
     The browser preferred by the user for external links.
     
     The key path `\.rawDefaultBrowser` should be used to observe changes. (`DefaultBrowser` isn't suitable for `@objc`.)
     */
    var defaultBrowser: DefaultBrowser {
        get {
            return rawDefaultBrowser
                .flatMap { DefaultBrowser(rawValue: $0) }
                ?? .fallback
        }
        set { rawDefaultBrowser = newValue.rawValue }
    }
}
