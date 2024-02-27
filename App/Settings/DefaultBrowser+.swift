//  DefaultBrowser+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import UIKit

extension DefaultBrowser {
    static var installedBrowsers: [Self] {
        allCases.filter {
            if let url = $0.checkCanOpenURL {
                UIApplication.shared.canOpenURL(url)
            } else {
                true
            }
        }
    }
}
