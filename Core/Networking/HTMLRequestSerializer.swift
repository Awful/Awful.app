//  HTMLRequestSerializer.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import Foundation

/**
    Ensures parameter values are within its string encoding by turning any outside characters into decimal HTML entities.
 
    - Warning: Ignores the `stringEncoding` property and always uses win1252.
    - Warning: Only works for parameters that resemble `[String: Any]`, where no values are themselves a collection.
 */
final class HTMLRequestSerializer: AFHTTPRequestSerializer {
    
    override init() {
        super.init()
        
        self.setQueryStringSerializationWith(queryString)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.setQueryStringSerializationWith(queryString)
    }
}

private func queryString(request: URLRequest, parameters: Any, error: NSErrorPointer) -> String {
    return (parameters as! [String: Any])
        .map { QueryStringPair(field: $0, value: $1) }
        .map { $0.URLEncodedValue }
        .joined(separator: "&")
}

private let charactersToBeEscapedInQueryString = ":/?&=;+!@#$()',~"
private let charactersToLeaveUnescapedInQueryString = "."

private struct QueryStringPair {
    let field: String
    let value: Any
    
    var URLEncodedValue: String {
        let escapedField = (field as NSString).awful_stringByAddingPercentEncodingAllowingCharacters(
            in: charactersToLeaveUnescapedInQueryString,
            escapingAdditionalCharactersIn: charactersToBeEscapedInQueryString,
            encoding: String.Encoding.windowsCP1252.rawValue) as String
        
        guard !(value is NSNull) else {
            return escapedField
        }
        
        let stringyValue = (value as? CustomStringConvertible)?.description ?? "\(value)"
        
        let escapedValue = (escape(stringyValue) as NSString).awful_stringByAddingPercentEncodingAllowingCharacters(in: charactersToLeaveUnescapedInQueryString, escapingAdditionalCharactersIn: charactersToBeEscapedInQueryString, encoding: String.Encoding.windowsCP1252.rawValue) as String
        
        return "\(escapedField)=\(escapedValue)"
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

private func escape(_ s: String) -> String {
    let scalars = s.unicodeScalars.flatMap { (c: UnicodeScalar) -> [UnicodeScalar] in
        if iswin1252(c: c) {
            return [c]
        } else {
            return Array("&#\(c.value);".unicodeScalars)
        }
    }
    return String(String.UnicodeScalarView(scalars))
}
