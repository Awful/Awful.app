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
        let scanner: Scanner
        do {
            scanner = try Scanner(string: findModelIdentifier())
        }
        catch {
            Log.e("Could not determine Handoff capability: \(error)")
            return false
        }

        var major: Int = Int.min
        if scanner.scanString("iPad", into: nil), scanner.scanInt(&major) {
            return major >= 2
        } else if scanner.scanString("iPhone", into: nil), scanner.scanInt(&major) {
            return major >= 5
        } else if scanner.scanString("iPod", into: nil), scanner.scanInt(&major) {
            return major >= 5
        } else {
            return false
        }
    }()
}

/// - Throws: ModelIdentifierError
private func findModelIdentifier() throws -> String {
    var size: Int = 0
    guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0 else {
        throw ModelIdentifierError.couldNotGetBufferSize
    }

    let bufferSize = Int(size) + 1
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    guard sysctlbyname("hw.machine", buffer, &size, nil, 0) == 0 else {
        throw ModelIdentifierError.failedToRetrieveModelIdentifier
    }

    buffer[Int(size)] = 0
    return String(cString: buffer)
}

private enum ModelIdentifierError: Error {
    case couldNotGetBufferSize
    case failedToRetrieveModelIdentifier
}
