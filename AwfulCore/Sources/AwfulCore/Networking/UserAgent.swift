//  UserAgent.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public let awfulUserAgent: String = {
    let info = Bundle.main.infoDictionary!
    let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
    let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
    let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
    let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"

    var osNameVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        var osName: String {
            #if os(iOS)
                return "iOS"
            #elseif os(watchOS)
                return "watchOS"
            #elseif os(tvOS)
                return "tvOS"
            #elseif os(macOS)
                return "OS X"
            #elseif os(Linux)
                return "Linux"
            #else
                return "Unknown"
            #endif
        }

        return "\(osName) \(versionString)"
    }

    return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
}()
