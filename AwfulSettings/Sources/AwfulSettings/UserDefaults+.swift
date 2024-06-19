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

    /**
     Returns the value for the setting, or the setting's default value.

     Does not register the default. This is not usually the correct way to use UserDefaults, and you should prefer using either `AppStorage` or `FoilDefaultStorage` whenever possible, as those do register the default.

     However, sometimes registering the default is a performance problem. That's when you go for this method.
     */
    func defaultingValue<T>(for setting: Setting<T>) -> T {
        (value(forKey: setting.key) as! T?) ?? setting.default
    }
}
