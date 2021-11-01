//  SettingsSection.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// These types are classes, and they inherit from NSObject, and some properties are `@objc`, in order to expose them to Objective-C. As soon as that's not necessary (i.e. SettingsBinding is gone or works a different way), these can all be changed to structs.

final class SettingsSection: NSObject {
    let info: [String: Any]
    
    init(info: [String: Any]) {
        self.info = info
    }
    
    @objc static let mainBundleSections = loadSections()!
}

// MARK: Loading settings from a plist

extension SettingsSection {
    static func loadSections(from resource: String = "Settings", in bundle: Bundle = .main) -> [SettingsSection]? {
        guard
            let url = bundle.url(forResource: resource, withExtension: "plist"),
            let plist = NSDictionary(contentsOf: url),
            let sections = plist["Sections"] as? [[String: Any]]
            else { return nil }
        
        return sections.map { SettingsSection(info: $0) }
    }
}

// MARK: Convenient accessors

extension SettingsSection {
    
    var defaultValues: [String: Any] {
        return settings.reduce(into: [:], { defaultValues, setting in
            if let key = setting.key, let value = setting.defaultValue {
                defaultValues[key] = value
            }
        })
    }
    
    var device: String? { info["Device"] as? String }

    var requiresSupportsAlternateAppIcons: Bool? { info["RequiresSupportsAlternateAppIcons"] as? Bool }
    
    @objc(SettingsSectionSetting) final class Setting: NSObject {
        @objc let info: [String: Any]
        
        init(info: [String: Any]) {
            self.info = info
        }
        
        var defaultValue: Any? {
            if #available(iOS 14.0, *), let value = info["Default~ios14"] {
                return value
            } else {
                return info["Default"]
            }
        }

        @objc var key: String? { info["Key"] as? String }
    }
    
    @objc var settings: [Setting] {
        let raw = info["Settings"] as? [[String: Any]] ?? []
        return raw.map { Setting(info: $0) }
    }
    
    var visibleInSettingsTab: Bool { info["VisibleInSettingsTab"] as? Bool ?? true }
}
