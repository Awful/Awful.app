//  HTMLRequestSerializer.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import Foundation

/// Ensures parameter values are within its string encoding by turning any outside characters into decimal HTML entities.
final class HTMLRequestSerializer: AFHTTPRequestSerializer {
    override func requestBySerializingRequest(request: NSURLRequest, withParameters parameters: AnyObject?) throws -> NSURLRequest {
        if let method = request.HTTPMethod where HTTPMethodsEncodingParametersInURI.contains(method) { return try super.requestBySerializingRequest(request, withParameters: parameters) }
        guard stringEncoding == NSWindowsCP1252StringEncoding else { fatalError("only works with win1252") }
        guard var dict = parameters as? [NSObject: AnyObject] else { return try super.requestBySerializingRequest(request, withParameters: parameters) }
        for key in dict.keys {
            guard let value = dict[key] as? String where !value.canBeConvertedToEncoding(stringEncoding) else { continue }
            dict[key] = escape(value)
        }
        return try super.requestBySerializingRequest(request, withParameters: dict)
    }
}

private func iswin1252(c: UnicodeScalar) -> Bool {
    // http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt
    switch c.value {
    case 0...0x7f, 0x81, 0x8d, 0x8f, 0x90, 0x9d, 0xa0...0xff, 0x152, 0x153, 0x160, 0x161, 0x178, 0x17d, 0x17e, 0x192, 0x2c6, 0x2dc, 0x2013, 0x2014, 0x2018...0x201a, 0x201c...0x201e, 0x2020...0x2022, 0x2026, 0x2030, 0x2039, 0x203a, 0x20ac, 0x2122:
        return true
    default:
        return false
    }
}

private func escape(s: String) -> String {
    let scalars = s.unicodeScalars.flatMap { (c: UnicodeScalar) -> [UnicodeScalar] in
        if iswin1252(c) {
            return [c]
        } else {
            return Array("&#\(c.value);".unicodeScalars)
        }
    }
    return String(String.UnicodeScalarView(scalars))
}
