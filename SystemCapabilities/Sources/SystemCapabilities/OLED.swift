//  OLED.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "OLED")

/// Device information that's not particularly convenient to retrieve.
public enum SystemCapabilities {

    /// Whether the device's main screen is OLED.
    public static let oled: Bool = {
        // Models are listed at https://ipsw.me/ and/or http://theiphonewiki.com/wiki/Models
        // Display technology is in each model's Wikipedia page.
        // Not gonna bother trying to guess at future models.
        guard let modelID = ModelIdentifier.makeFromSysctl() else { return false }
        switch modelID.device {
        case .iPhone:
            switch (modelID.major, modelID.minor) {
            case (10,3), (10,6), // iPhone X
                (11,2), // iPhone XS
                (11,4), (11,6), // iPhone XS Max
                (12,3), // iPhone 11 Pro
                (12,5), // iPhone 11 Pro Max
                (13,1), // iPhone 12 Mini
                (13,2), // iPhone 12
                (13,3), // iPhone 12 Pro
                (13,4), // iPhone 12 Pro Max
                (14,2), // iPhone 13 Pro
                (14,3), // iPhone 13 Pro Max
                (14,4), // iPhone 13 Mini
                (14,5), // iPhone 13
                (14,7), // iPhone 14
                (14,8), // iPhone 14 Plus
                (15,2), // iPhone 14 Pro
                (15,3), // iPhone 14 Pro Max
                (15,4), // iPhone 15
                (15,5), // iPhone 15 Plus
                (16,1), // iPhone 15 Pro
                (16,2): // iPhone 15 Pro Max
                return true
            case (_,_):
                return false
            }
        case .iPad:
            switch (modelID.major, modelID.minor) {
            case (16,3), (16,4), (16,5), (16,6): // iPad Pro (M4) aka iPad Pro (7th generation)
                return true
            case (_,_):
                return false
            }
        }
    }()
}

private struct ModelIdentifier {
    let device: Device
    let major: Int
    let minor: Int

    enum Device {
        case iPad, iPhone
    }

    init?(_ rawValue: String) {
        let scanner = Scanner(string: rawValue)
        if scanner.scanString("iPhone") != nil {
            device = .iPhone
        } else if scanner.scanString("iPad") != nil {
            device = .iPad
        } else {
            return nil
        }

        guard let major = scanner.scanInt(),
              scanner.scanString(",") != nil,
              let minor = scanner.scanInt()
        else { return nil }
        self.major = major
        self.minor = minor
    }

    static func makeFromSysctl() -> ModelIdentifier? {
        var size: Int = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0 else {
            logger.error("could not find model identifier: could not get buffer size")
            return nil
        }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size + 1)
        defer { buffer.deallocate() }

        guard sysctlbyname("hw.machine", buffer, &size, nil, 0) == 0 else {
            logger.error("could not find model identifier")
            return nil
        }

        buffer[Int(size)] = 0
        return ModelIdentifier(String(cString: buffer))
    }
}
