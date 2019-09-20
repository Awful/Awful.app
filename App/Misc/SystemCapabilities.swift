//  SystemCapabilities.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import class ScannerShim.Scanner
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
        #if targetEnvironment(macCatalyst)
        // Supported Handoff devices: https://support.apple.com/en-ca/HT204689
        // Macs that can run 10.15 Catalina (when UIKit for Mac shipped): https://www.apple.com/ca/macos/catalina-preview/
        // 100% overlap :)
        return true
        #else
        // Handoff starts at iPhone 5, iPod Touch 5G, iPad 4G, iPad Mini 1: http://support.apple.com/en-us/HT6555
        // Models are listed at https://ipsw.me/ and/or http://theiphonewiki.com/wiki/Models
        // Let's assume all future models also support Handoff.
        let scanner = Scanner(string: modelIdentifier)
        if scanner.scanString("iPad") != nil, let major = scanner.scanInt() {
            return major >= 2
        } else if scanner.scanString("iPhone") != nil, let major = scanner.scanInt() {
            return major >= 5
        } else if scanner.scanString("iPod") != nil, let major = scanner.scanInt() {
            return major >= 5
        } else {
            return false
        }
        #endif
    }()

    static let oled: Bool = {
        // Models are listed at https://ipsw.me/ and/or http://theiphonewiki.com/wiki/Models
        // Not gonna bother trying to guess at future models.
        let scanner = Scanner(string: modelIdentifier)
        guard
            scanner.scanString("iPhone") != nil,
            let major = scanner.scanInt(),
            scanner.scanString(",") != nil,
            let minor = scanner.scanInt()
            else { return false }
        switch (major, minor) {
        case (10, 3), (10, 6): // iPhone X
            return true
        case (11, 2): // iPhone XS
            return true
        case (11, 4), (11, 6): // iPhone XS Max
            return true
        case (12, 3): // iPhone 11 Pro
            return true
        case (12, 5): // iPhone 11 Pro Max
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
