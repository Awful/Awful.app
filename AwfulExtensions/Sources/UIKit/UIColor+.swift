//  UIColor+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UIColor {
    /**
     Creates a color based on an HTML hexadecimal string value.

     A leading `#` is allowed, and ignored. Values of 3, 4, 6, and 8 digits are accepted. The 4 and 8 digit variations include the alpha component at the end.
     */
    convenience init?(hex hexString: String) {
        let scanner = Scanner(string: hexString)
        _ = scanner.scanString("#")
        let start = scanner.currentIndex
        guard let hex = scanner.scanUInt64(representation: .hexadecimal) else { return nil }
        let length = scanner.string.distance(from: start, to: scanner.currentIndex)
        switch length {
        case 3:
            self.init(
                red: CGFloat((hex & 0xF00) >> 8) / 15,
                green: CGFloat((hex & 0x0F0) >> 4) / 15,
                blue: CGFloat((hex & 0x00F) >> 0) / 15,
                alpha: 1)
        case 4:
            self.init(
                red: CGFloat((hex & 0xF000) >> 12) / 15,
                green: CGFloat((hex & 0x0F00) >> 8) / 15,
                blue: CGFloat((hex & 0x00F0) >> 4) / 15,
                alpha: CGFloat((hex & 0x000F) >> 0) / 15)
        case 6:
            self.init(
                red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                blue: CGFloat((hex & 0x0000FF) >> 0) / 255,
                alpha: 1)
        case 8:
            self.init(
                red: CGFloat((hex & 0xFF000000) >> 24) / 255,
                green: CGFloat((hex & 0x00FF0000) >> 16) / 255,
                blue: CGFloat((hex & 0x0000FF00) >> 8) / 255,
                alpha: CGFloat((hex & 0x000000FF) >> 0) / 255)
        default:
            return nil
        }
    }

    /**
     An approximate hexadecimal string representation of this color.

     The returned value can be passed to `UIColor(hex:)`.
     */
    var hexCode: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "" }
        func hexy(_ f: CGFloat) -> String {
            return String(lround(Double(f) * 255), radix: 16, uppercase: false)
        }
        return "#" + [red, green, blue].map(hexy).joined(separator: "")
    }
}
