//  SettingsBinding.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@protocol SettingsBindable

/**
 * Binds a relevant property to the AwfulSettings key.
 */
@property (copy, nonatomic) NSString *awful_setting;

@end

/**
 * Binds the `text` property to the (presumably `NSString` value of the) `settingsKey`.
 */
@interface UILabel (AwfulSettingsBinding) <SettingsBindable>

/**
 * The `text` property will use this format string if available, replacing the string `%@` with the setting's current value.
 */
@property (copy, nonatomic) NSString *awful_settingFormatString;

@end

/**
 * Binds the `value` property to the `double` value of the `settingsKey`.
 *
 * In addition, if the setting describes a `Minimum`, `Maximum`, and/or `Increment`, those values are set to the `minimumValue`, `maximumValue`, and `stepValue` properties.
 */
@interface UIStepper (AwfulSettingsBinding) <SettingsBindable> @end

/**
 * Binds the `on` property to the `boolValue` of the `settingsKey`.
 */
@interface UISwitch (AwfulSettingsBinding) <SettingsBindable> @end
