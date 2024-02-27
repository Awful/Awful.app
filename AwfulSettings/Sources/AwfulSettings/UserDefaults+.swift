//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public extension UserDefaults {
    /**
     Returns the value for the setting.

     Assumes the setting has already been registered if its `DefaultsValue` is non-`Optional`.
    */
    func value<T>(for setting: Setting<T>) -> T {
        value(forKey: setting.key) as! T
    }
}
