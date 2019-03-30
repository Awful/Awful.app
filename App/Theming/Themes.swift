//  Themes.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/**
    Collects colors, images, fonts, and other presentation bits into a unified theme.

    Themes are loaded from a file called Themes.plist, a dictionary mapping names to dictionaries of theme attributes. Theme attributes can take the following forms:

        * "parent", whose value is the name of a parent theme. Values missing from one theme are looked up in its parent.
        * "xxxColor", whose value is either a CSS hexadecimal color code (with an optional alpha component) or the name of a pattern image in the main bundle.
        * "xxxCSS", whose value is a filename of a resource in the main bundle.
        * "keyboardAppearance", whose value is either "dark" or "light".
        * "scrollIndicatorStyle", whose value is either "dark" or "light".
        * "relevantForumID", whose value is the ID of the forum that should default to the theme.

    Additionally, theme attributes can themselves be dictionaries. The dictionaries will all be flattened on load. This can be handy for sectioning off related attributes. (The name of a section is ignored.)

    The theme named "default" is special: it is the parent of all themes that do not specify a parent. It's the root theme. All themes eventually point back to the default theme.
*/
final class Theme {
    let name: String
    fileprivate let dictionary: [String: Any]
    fileprivate var parent: Theme?
    
    fileprivate init(name: String, dictionary: [String: Any]) {
        self.name = name
        self.dictionary = flatten(dictionary)
    }

    enum Mode: Hashable {
        case light, dark
    }
}

private func flatten<K, V>(_ dictionary: [K: V]) -> [K: V] {
    return dictionary.reduce([:]) { (accum, kvpair) in
        var accum = accum
        if let nested = kvpair.1 as? [K: V] {
            for (k, v) in flatten(nested) {
                accum[k] = v
            }
        } else {
            accum[kvpair.0] = kvpair.1
        }
        return accum
    }
}

// MARK: Dictionary accessors

extension Theme {

    /// The name of the theme, suitable for presentation.
    var descriptiveName: String {
        return dictionary["descriptiveName"] as? String ?? name
    }
    
    /// A color representative of the theme, suitable for presentation.
    var descriptiveColor: UIColor {
        return self["descriptive"]!
    }
    
    /// The ID of the forum for which the theme is designed, or nil if there was no forum in mind.
    var forumID: String? {
        return dictionary["relevantForumID"] as! String?
    }
    
    /// The desired appearance for the keyboard. If unspecified by the theme and its ancestors, returns .Default.
    var keyboardAppearance: UIKeyboardAppearance {
        let appearance = dictionary["keyboardAppearance"] as? String
            ?? parent?["keyboardAppearance"]
            ?? "default"

        switch appearance {
        case "Dark", "dark":
            return .dark
        case "Light", "light":
            return .light
        case "default":
            return .default
        default:
            fatalError("Unrecognized keyboard appearance: \(appearance) (in theme \(name)")
        }
    }
    
    /// The desired scroll indicator style for scrollbars. Must be specified by the theme or one of its ancestors.
    var scrollIndicatorStyle: UIScrollView.IndicatorStyle {
        guard let style = dictionary["scrollIndicatorStyle"] as? String ?? parent?["scrollIndicatorStyle"] else { return .default }

        switch style {
        case "Dark", "dark":
            return .black
        case "Light", "light":
            return .white
        default:
            fatalError("Unrecognized scroll indicator style: \(style) (in theme \(name))")
        }
    }

    /// The named color (the "Color" suffix is optional).
    subscript(color colorName: String) -> UIColor? {
        let key = colorName.hasSuffix("Color") ? colorName : "\(colorName)Color"
        guard let value = dictionary[key] as? String else { return parent?[key] }

        if let hexColor = UIColor(hex: value) {
            return hexColor
        }
        else if let patternImage = UIImage(named: value) {
            return UIColor(patternImage: patternImage)
        }
        else {
            fatalError("Unrecognized theme attribute color: \(value) (in theme \(name), for key \(colorName)")
        }
    }

    /**
     The named color (the "Color" suffix in the key is optional).

     - Note: If type inference is leading you to do things like `theme["coolKey"] as UIColor?`, consider `theme[color: "coolKey"]` instead.
     */
    subscript(colorName: String) -> UIColor? {
        return self[color: colorName]
    }

    /// The named theme attribute as a string.
    subscript(string key: String) -> String? {
        guard let value = dictionary[key] as? String ?? parent?[key] else { return nil }
        if key.hasSuffix("CSS") {
            guard let url = Bundle.main.url(forResource: value, withExtension: nil) else {
                fatalError("Missing CSS file for \(key): \(value)")
            }

            do {
                return try String(contentsOf: url, encoding: .utf8)
            }
            catch {
                fatalError("Could not find CSS file \(value) (in theme \(name), for key \(key)): \(error)")
            }
        }
        else {
            return value
        }
    }

    /**
     The named theme attribute as a string.

     - Note: If type inference is leading you to do things like `theme["coolKey"] as String?`, consider `theme[string: "coolKey"]` instead.
     */
    subscript(key: String) -> String? {
        return self[string: key]
    }
}

// MARK: - Comparable

extension Theme: Comparable {
    static func == (lhs: Theme, rhs: Theme) -> Bool {
        return lhs === rhs
    }

    /// Themes are ordered: default, dark, <rest sorted by name>
    static func < (lhs: Theme, rhs: Theme) -> Bool {
        if lhs.name == "default" {
            return rhs.name != "default"
        } else if rhs.name == "default" {
            return false
        }

        if lhs.name == "dark" {
            return rhs.name != "dark"
        } else if rhs.name == "dark" {
            return false
        }

        return lhs.name < rhs.name
    }
}

// MARK: - Themes based on forums and settings

private let bundledThemes: [String: Theme] = {
    let URL = Bundle.main.url(forResource: "Themes", withExtension: "plist")!
    let plist = NSDictionary(contentsOf: URL) as! [String: Any]

    var themes = [String: Theme]()

    for (name, dictionary) in plist {
        themes[name] = Theme(name: name, dictionary: dictionary as! [String: Any])
    }

    for (name, var theme) in themes {
        if name != "default" {
            let parentName = theme.dictionary["parent"] as? String ?? "default"
            theme.parent = themes[parentName]!
        }
    }

    return themes
}()

extension Theme {
    static func defaultTheme(mode: Mode = currentMode) -> Theme {
        let themeName: String
        switch mode {
        case .dark:
            themeName = UserDefaults.standard.defaultDarkTheme
        case .light:
            themeName = UserDefaults.standard.defaultLightTheme
        }
        return bundledThemes[themeName]!
    }

    class var allThemes: [Theme] {
        return bundledThemes.values.sorted()
    }

    private static var currentMode: Mode {
        return UserDefaults.standard.isDarkModeEnabled ? .dark : .light
    }
    
    static func currentTheme(for forum: Forum, mode: Mode = currentMode) -> Theme {
        if let themeName = themeNameForForum(identifiedBy: forum.forumID, mode: mode) {
            return bundledThemes[themeName]!
        } else {
            return defaultTheme(mode: mode)
        }
    }
    
    private static func themeNameForForum(identifiedBy forumID: String, mode: Mode) -> String? {
        return UserDefaults.standard.string(forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
    }
    
    /// Posts `Themes.themeForForumDidChangeNotification`.
    static func setThemeName(_ themeName: String?, forForumIdentifiedBy forumID: String, modes: Set<Mode>) {
        for mode in modes {
            UserDefaults.standard.set(themeName, forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
        }
        
        var userInfo = [Theme.forumIDKey: forumID]
        if let themeName = themeName {
            userInfo[Theme.themeNameKey] = themeName
        }
        NotificationCenter.default.post(name: Theme.themeForForumDidChangeNotification, object: self, userInfo: userInfo)
    }

    private static func defaultsKeyForForum(identifiedBy forumID: String, mode: Mode) -> String {
        switch mode {
        case .light:
            return "theme-light-\(forumID)"
        case .dark:
            return "theme-dark-\(forumID)"
        }
    }
    
    /**
     Posted when `Theme.setThemeName(_:forForumIdentifiedBy:)` is called. The notification object is the `Theme` class itself. The user info dictionary always includes a value for `Theme.forumIDKey`, and it includes a value for `Theme.themeNameKey` if a theme name was specified.
     */
    static var themeForForumDidChangeNotification: Notification.Name {
        return Notification.Name("Awful theme for forum did change")
    }
    
    static let forumIDKey = "forumID"
    static let themeNameKey = "themeName"
}

extension Theme {
    static var forumSpecificDefaults: [String: Any] {
        let modeless = [
            "25": "Gas Chamber",
            "26": "FYAD",
            "219": "YOSPOS",
            "268": "BYOB"]
        var altogether: [String: Any] = [:]
        for (forumID, themeName) in modeless {
            altogether["theme-dark-\(forumID)"] = themeName
            altogether["theme-light-\(forumID)"] = themeName
        }
        return altogether
    }
}
