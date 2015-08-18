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
@objc final class Theme: NSObject, Comparable {
    let name: String
    private let dictionary: [String: AnyObject]
    private var parent: Theme?
    
    private init(name: String, dictionary: [String: AnyObject]) {
        self.name = name
        self.dictionary = flatten(dictionary)
    }
    
    /// The name of the theme, suitable for presentation.
    var descriptiveName: String {
        return (dictionary["descriptiveName"] as! String?) ?? name
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
        let appearance = (dictionary["keyboardAppearance"] as! String?) ?? parent?["keyboardAppearance"] ?? "default"
        switch appearance {
        case "Dark", "dark":
            return .Dark
        case "Light", "light":
            return .Light
        case "default":
            return .Default
        default:
            fatalError("Unrecognized keyboard appearance: \(appearance) (in theme \(name)")
        }
    }
    
    /// The desired scroll indicator style for scrollbars. Must be specified by the theme or one of its ancestors.
    var scrollIndicatorStyle: UIScrollViewIndicatorStyle {
        if let style = (dictionary["scrollIndicatorStyle"] as! String?) ?? parent?["scrollIndicatorStyle"] {
            switch style {
            case "Dark", "dark":
                return .Black
            case "Light", "light":
                return .White
            default:
                fatalError("Unrecognized scroll indicator style: \(style) (in theme \(name))")
            }
        } else {
            return .Default
        }
    }
    
    /// The named color (the "Color" suffix is optional).
    subscript(colorName: String) -> UIColor? {
        @objc(colorNamed:) get {
            let key = colorName.hasSuffix("Color") ? colorName : "\(colorName)Color"
            if let value = dictionary[key] as? String {
                if let hexColor = UIColor.awful_colorWithHexCode(value) {
                    return hexColor
                } else if let patternImage = UIImage(named: value) {
                    return UIColor(patternImage: patternImage)
                } else {
                    fatalError("Unrecognized theme attribute color: \(value) (in theme \(name), for key \(colorName)")
                }
            } else {
                return parent?[key]
            }
        }
    }
    
    /// The named theme attribute as a string.
    subscript(key: String) -> String? {
        @objc(stringNamed:) get {
            if let value = (dictionary[key] as! String?) ?? parent?[key] {
                if key.hasSuffix("CSS") {
                    let URL = NSBundle.mainBundle().URLForResource(value, withExtension: nil)!
                    var CSS = NSString()
                    do {
                        try CSS = NSString(contentsOfURL: URL, usedEncoding: nil)
                    }
                    catch {
                        fatalError("Could not find CSS file \(value) (in theme \(name), for key \(key)")
                    }
                    return CSS as String
                } else {
                    return value
                }
            } else {
                return nil
            }
        }
    }
    
    /// A subscript accessible to Objective-C.
    subscript(key: String) -> AnyObject? {
        if key.hasSuffix("Color") {
            return self[key] as UIColor?
        } else {
            return self[key] as String?
        }
    }
}

func == (lhs: Theme, rhs: Theme) -> Bool {
    return lhs === rhs
}

/// Themes are ordered: default, dark, <rest sorted by name>
func < (lhs: Theme, rhs: Theme) -> Bool {
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

private func flatten<K, V>(dictionary: [K: V]) -> [K: V] {
    return dictionary.reduce([:]) { (var accum, kvpair) in
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

private let bundledThemes: [String: Theme] = {
    let URL = NSBundle.mainBundle().URLForResource("Themes", withExtension: "plist")!
    let plist = NSDictionary(contentsOfURL: URL) as! [String: AnyObject]
    
    var themes = [String: Theme]()
    
    for (name, dictionary) in plist {
        themes[name] = Theme(name: name, dictionary: dictionary as! [String: AnyObject])
    }
    
    for (name, var theme) in themes {
        if name != "default" {
            let parentName = theme.dictionary["parent"] as? String ?? "default"
            theme.parent = themes[parentName]!
        }
    }
    
    return themes
}()

// MARK: Themes based on forums and preferences

extension Theme {
    class var defaultTheme: Theme {
        return bundledThemes["default"]!
    }
    
    class var currentTheme: Theme {
        if AwfulSettings.sharedSettings().darkTheme {
            return bundledThemes["dark"]!
        } else {
            return defaultTheme
        }
    }
    
    class var allThemes: [Theme] {
        return bundledThemes.values.sort()
    }
    
    class func currentThemeForForum(forum: Forum) -> Theme {
        if let name = AwfulSettings.sharedSettings().themeNameForForumID(forum.forumID) {
            return bundledThemes[name]!
        } else {
            return currentTheme
        }
    }
    
    class func themesForForum(forum: Forum) -> [Theme] {
        let ubiquitousNames = AwfulSettings.sharedSettings().ubiquitousThemeNames as! [String]? ?? []
        let themes = bundledThemes.values.filter {
            $0.forumID == forum.forumID || $0.forumID == nil || ubiquitousNames.contains($0.name)
        }
        return themes.sort()
    }
}
