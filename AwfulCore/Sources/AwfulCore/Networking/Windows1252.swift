//  Windows1252.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Turns the pair value into a string, then turns everything in key and value outside win1252 into HTML entities.
func win1252Escaped(
    _ pair: KeyValuePairs<String, Any>.Element
) -> KeyValuePairs<String, String>.Element {
    func escape(_ s: String) -> String {
        let escaped = s.unicodeScalars.lazy.flatMap { (c: Unicode.Scalar) -> String.UnicodeScalarView in
            if c.isWin1252 {
                return String.UnicodeScalarView([c])
            } else {
                return "&#\(c.value);".unicodeScalars
            }
        }
        return String(String.UnicodeScalarView(escaped))
    }
    return (key: escape(pair.key), value: escape("\(pair.value)"))
}

extension Unicode.Scalar {
    var isWin1252: Bool {
        // http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt
        switch value {
        case 0...0x7f, 0x81, 0x8d, 0x8f, 0x90, 0x9d, 0xa0...0xff, 0x152, 0x153, 0x160, 0x161, 0x178, 0x17d, 0x17e, 0x192, 0x2c6, 0x2dc, 0x2013, 0x2014, 0x2018...0x201a, 0x201c...0x201e, 0x2020...0x2022, 0x2026, 0x2030, 0x2039, 0x203a, 0x20ac, 0x2122:
            return true
        default:
            return false
        }
    }
}
