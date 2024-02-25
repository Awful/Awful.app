//  Themes.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulModelTypes
import AwfulSettings
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
public class Theme {
    public let name: String
    fileprivate let dictionary: [String: Any]
    fileprivate var parent: Theme?
    
    fileprivate init(name: String, dictionary: [String: Any]) {
        self.name = name
        self.dictionary = flatten(dictionary)
    }

    public enum Mode: CaseIterable, Hashable {
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
    public var descriptiveName: String {
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
    
    /// Does the theme use standed system font or rounded
    public var roundedFonts: Bool {
        return dictionary["roundedFonts"] as? Bool ?? false
    }
    
    /// The desired appearance for the keyboard. If unspecified by the theme and its ancestors, returns .Default.
    public var keyboardAppearance: UIKeyboardAppearance {
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
    public var scrollIndicatorStyle: UIScrollView.IndicatorStyle {
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

    public subscript(bool key: String) -> Bool? {
        return dictionary[key] as? Bool ?? parent?[bool: key]
    }

    /// The named color (the "Color" suffix is optional).
    public subscript(color colorName: String) -> UIColor? {
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
    public subscript(colorName: String) -> UIColor? {
        return self[color: colorName]
    }

    public subscript(double key: String) -> Double? {
        return dictionary[key] as? Double ?? parent?[double: key]
    }

    /// The named theme attribute as a string.
    public subscript(string key: String) -> String? {
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
    public subscript(key: String) -> String? {
        return self[string: key]
    }
}

// MARK: - Comparable

extension Theme: Comparable {
    public static func == (lhs: Theme, rhs: Theme) -> Bool {
        return lhs === rhs
    }

    public static func < (lhs: Theme, rhs: Theme) -> Bool {
        func givePriority(to name: String) -> Bool? {
            if lhs.name == name {
                return rhs.name != name
            } else if rhs.name == name {
                return false
            } else {
                return nil
            }
        }

        return givePriority(to: "default")
            ?? givePriority(to: "dark")
            ?? givePriority(to: "alternateDefault")
            ?? givePriority(to: "alternateDark")
            ?? givePriority(to: "brightLight")
            ?? givePriority(to: "oledDark")
            ?? (lhs.descriptiveName < rhs.descriptiveName)
    }
}

// MARK: - Bundled themes

private let bundledThemes: [String: Theme] = {
    let URL = Bundle.module.url(forResource: "Themes", withExtension: "plist")!
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
    public static func theme(named themeName: String) -> Theme? {
        return bundledThemes.values.first { $0.name == themeName }
    }

    public static func theme(describedAs description: String) -> Theme? {
        return bundledThemes.values.first { $0.descriptiveName == description }
    }
}

// MARK: - Getting themes with settings

extension Theme {
    public static func defaultTheme(
        mode: Mode? = nil /* currentMode */
    ) -> Theme {
        let theme: BuiltInTheme = switch mode ?? currentMode {
        case .dark:
            defaultDarkTheme
        case .light:
            defaultLightTheme
        }
        
        // If a theme was renamed, this will prevent a crash on launch
        return bundledThemes[theme.rawValue] ?? (mode == .light ? bundledThemes["default"] : bundledThemes["dark"])!
    }

    @FoilDefaultStorage(Settings.defaultDarkThemeName) private static var defaultDarkTheme
    @FoilDefaultStorage(Settings.defaultLightThemeName) private static var defaultLightTheme

    public class var allThemes: [Theme] {
        return bundledThemes.values.sorted()
    }

    private static var currentMode: Mode {
        return darkMode ? .dark : .light
    }

    @FoilDefaultStorage(Settings.darkMode) private static var darkMode

    public static func currentTheme(for forumID: ForumID, mode: Mode? = nil /* currentMode */) -> Theme {
        let mode = mode ?? currentMode
        if let themeName = themeNameForForum(identifiedBy: forumID.rawValue, mode: mode) {
            return bundledThemes[themeName]!
        } else {
            return defaultTheme(mode: mode)
        }
    }
    
    private static func themeNameForForum(identifiedBy forumID: String, mode: Mode) -> String? {
        return UserDefaults.standard.string(forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
    }
    
    /// Posts `Themes.themeForForumDidChangeNotification`.
    public static func setThemeName(_ themeName: String?, forForumIdentifiedBy forumID: String, modes: Set<Mode>) {
        for mode in modes {
            UserDefaults.standard.set(themeName, forKey: defaultsKeyForForum(identifiedBy: forumID, mode: mode))
        }
        
        var userInfo = [Theme.forumIDKey: forumID]
        if let themeName = themeName {
            userInfo[Theme.themeNameKey] = themeName
        }
        NotificationCenter.default.post(name: Theme.themeForForumDidChangeNotification, object: self, userInfo: userInfo)
    }

    public static func defaultsKeyForForum(identifiedBy forumID: String, mode: Mode) -> String {
        switch mode {
        case .light:
            return "theme-light-\(forumID)"
        case .dark:
            return "theme-dark-\(forumID)"
        }
    }

    public static var forumsWithSpecificThemes: Set<String> {
        func extractForumID(_ key: String) -> String? {
            let components = key.split(separator: "-")
            guard
                components.count == 3,
                components[0] == "theme",
                ["light", "dark"].contains(components[1]),
                Int(components[2]) != nil
                else { return nil }
            return String(components[2])
        }
        return Set(UserDefaults.standard
            .dictionaryRepresentation().keys
            .compactMap(extractForumID(_:)))
    }
    
    /**
     Posted when `Theme.setThemeName(_:forForumIdentifiedBy:)` is called. The notification object is the `Theme` class itself. The user info dictionary always includes a value for `Theme.forumIDKey`, and it includes a value for `Theme.themeNameKey` if a theme name was specified.
     */
    public static let themeForForumDidChangeNotification: Notification.Name = .init("Awful theme for forum did change")
    
    static let forumIDKey = "forumID"
    static let themeNameKey = "themeName"
}

extension Theme {
    public static var forumSpecificDefaults: [String: Any] {
        let modeless = [
            "25": "Gas Chamber",
            "26": "FYAD",
            "154": "FYAD",
            "666": "FYAD",
            "219": "YOSPOS",
            "268": "BYOB",
            "196": "BYOB"]
        var altogether: [String: Any] = [:]
        for (forumID, themeName) in modeless {
            altogether["theme-dark-\(forumID)"] = themeName
            altogether["theme-light-\(forumID)"] = themeName
        }
        return altogether
    }
}

public enum FontWeight: String, CaseIterable {
    case ultraLight = "ultraLight"
    case thin = "thin"
    case light = "light"
    case regular = "regular"
    case medium = "medium"
    case semibold = "semibold"
    case bold = "bold"
    case heavy = "heavy"
    case black = "black"
    
    public var weight: UIFont.Weight {
        switch self {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }
    
    static func weight(for string: String) -> UIFont.Weight? {
        return FontWeight(rawValue: string)?.weight
    }
}

