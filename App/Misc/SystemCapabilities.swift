//  SystemCapabilities.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

enum SystemCapabilities {

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
        case (10, 3), (10, 6), // iPhone X
            (11, 2), // iPhone XS
            (11, 4), (11, 6), // iPhone XS Max
            (12, 3), // iPhone 11 Pro
            (12, 5), // iPhone 11 Pro Max
            (13, 1), // iPhone 12 Mini
            (13, 2), // iPhone 12
            (13, 3), // iPhone 12 Pro
            (13, 4), // iPhone 12 Pro Max
            (14, 2), // iPhone 13 Pro
            (14, 3), // iPhone 13 Pro Max
            (14, 4), // iPhone 13 Mini
            (14, 5): // iPhone 13
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
