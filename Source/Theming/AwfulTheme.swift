//  AwfulTheme.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension AwfulTheme {
    /**
        Returns the named color. The "Color" suffix is optional.

        Crashes if the key does not exist in the theme or any of its parent themes, or if the value is something other than a UIColor.
    */
    subscript(colorName: String) -> UIColor {
        @objc(colorForKeyedSubscript:) get {
            let key = colorName.hasSuffix("Color") ? colorName : "\(colorName)Color"
            let value: AnyObject? = self[key]
            return value as UIColor
        }
    }
    
    /// Returns a String or a UIColor for the given key, or nil if there is no value for the key.
    subscript(key: String) -> AnyObject? {
        return objectForKey(key)
    }
}
