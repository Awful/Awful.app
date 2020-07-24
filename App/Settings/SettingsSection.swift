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
            guard let key = setting.key else { return }

            if #available(iOS 13.0, *), let value = setting.defaultValueAsOfiOS13 {
                defaultValues[key] = value
            } else if let value = setting.defaultValue {
                defaultValues[key] = value
            }
        })
    }
    
    var device: String? {
        return info["Device"] as? String
    }
    
    var deviceCapability: String? {
        return info["DeviceCapability"] as? String
    }
    
    @objc(SettingsSectionSetting) final class Setting: NSObject {
        @objc let info: [String: Any]
        
        init(info: [String: Any]) {
            self.info = info
        }
        
        var defaultValue: Any? {
            return info["Default"]
        }

        var defaultValueAsOfiOS13: Any? {
            return info["Default~ios13"]
        }
        
        @objc var key: String? {
            return info["Key"] as? String
        }
    }
    
    @objc var settings: [Setting] {
        let raw = info["Settings"] as? [[String: Any]] ?? []
        return raw.map { Setting(info: $0) }
    }
    
    var visibleInSettingsTab: Bool {
        return info["VisibleInSettingsTab"] as? Bool ?? true
    }
}
