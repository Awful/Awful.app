// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

//  UserDefaults+Settings
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/*
 KVO-compliant properties for various Awful settings.

 `UserDefaults` instances emit KVO notifications when values change. In order to use these with Swift's awesome `observe(keyPath:…)` methods, we need to:

    * Expose a property on `UserDefaults` for each key we're interested in.
    * Either have that property's name match the key, or add some KVO machinery so changes to the key notify observers of the property. (That machinery is the `automaticallyNotifiesObserversOf…` and `keyPathsForValuesAffecting…` class properties. We turn off automatic notification because we only want notifications when the underlying defaults key changes, and we specify the underlying defaults key as a key path whose value affects the property.)

 To add settings, see `UserDefaults+Settings.swift`. To change what gets generated for each setting, see `UserDefaults+Settings.stencil`.
 */
extension UserDefaults {


    @objc dynamic var automaticDarkModeBrightnessThresholdPercentKey: Bool {
        get { return bool(forKey: SettingsKeys.automaticDarkModeBrightnessThresholdPercentKey) }
        set { set(newValue, forKey: SettingsKeys.automaticDarkModeBrightnessThresholdPercentKey) }
    }

    @objc private class var automaticallyNotifiesObserversOfAutomaticDarkModeBrightnessThresholdPercentKey: Bool {
        return false
    }

    @objc private class var keyPathsForValuesAffectingAutomaticDarkModeBrightnessThresholdPercentKey: Set<String> {
        return [SettingsKeys.automaticDarkModeBrightnessThresholdPercentKey]
    }


    @objc dynamic var automaticallyEnableDarkModeKey: Bool {
        get { return bool(forKey: SettingsKeys.automaticallyEnableDarkModeKey) }
        set { set(newValue, forKey: SettingsKeys.automaticallyEnableDarkModeKey) }
    }

    @objc private class var automaticallyNotifiesObserversOfAutomaticallyEnableDarkModeKey: Bool {
        return false
    }

    @objc private class var keyPathsForValuesAffectingAutomaticallyEnableDarkModeKey: Set<String> {
        return [SettingsKeys.automaticallyEnableDarkModeKey]
    }


    @objc dynamic var isDarkModeEnabledKey: Bool {
        get { return bool(forKey: SettingsKeys.isDarkModeEnabledKey) }
        set { set(newValue, forKey: SettingsKeys.isDarkModeEnabledKey) }
    }

    @objc private class var automaticallyNotifiesObserversOfIsDarkModeEnabledKey: Bool {
        return false
    }

    @objc private class var keyPathsForValuesAffectingIsDarkModeEnabledKey: Set<String> {
        return [SettingsKeys.isDarkModeEnabledKey]
    }

}
