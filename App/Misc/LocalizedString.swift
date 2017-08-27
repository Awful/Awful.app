//
//  LocalizedString.swift
//  Awful
//
//  Created by Nolan Waite on 2017-08-27.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation

internal func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, bundle: Bundle(for: AppDelegate.self), comment: "")
}
