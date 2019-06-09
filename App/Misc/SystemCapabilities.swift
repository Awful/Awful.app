//  SystemCapabilities.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

enum SystemCapabilities {
    static let changeAppIcon: Bool = {
        if #available(iOS 10.3, *) {
            return UIApplication.shared.supportsAlternateIcons
        }
        else {
            return false
        }
    }()

    /**
     Whether the current device is capable of Handoff.

     - Note: Does not take into account the user's current Handoff settings. That is, `handoff` can return `true` when the user has turned off Handoff.
     */
    static let handoff: Bool = {
        // Handoff starts at iPhone 5, iPod Touch 5G, iPad 4G, iPad Mini 1: http://support.apple.com/en-us/HT6555
        // Models are listed at http://theiphonewiki.com/wiki/Models
        // Let's assume all future models also support Handoff.
        let scanner = Scanner(string: modelIdentifier)
        if scanner.scan("iPad"), let major = scanner.scanInt() {
            return major >= 2
        } else if scanner.scan("iPhone"), let major = scanner.scanInt() {
            return major >= 5
        } else if scanner.scan("iPod"), let major = scanner.scanInt() {
            return major >= 5
        } else {
            return false
        }
    }()

    static let oled: Bool = {
        // Models are listed at http://theiphonewiki.com/wiki/Models
        // Not gonna bother trying to guess at future models.
        let scanner = Scanner(string: modelIdentifier)
        guard
            scanner.scan("iPhone"),
            let major = scanner.scanInt(),
            scanner.scan(","),
            let minor = scanner.scanInt()
            else { return false }
        switch (major, minor) {
        case (10, 3), (10, 6): // iPhone X
            return true
        case (11, 2): // iPhone XS
            return true
        case (11, 6): // iPhone XS Max
            return true
        default:
            return false
        }
    }()
}

private let modelIdentifier: String = {
    var size: Int = 0
    guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0 else {
        Log.e("could not find model identifier: could not get buffer size")
        return ""
    }

    let bufferSize = Int(size) + 1
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    guard sysctlbyname("hw.machine", buffer, &size, nil, 0) == 0 else {
        Log.e("could not find model identifier")
        return ""
    }

    buffer[Int(size)] = 0
    return String(cString: buffer)
}()
