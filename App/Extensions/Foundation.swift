//  Foundation.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension Bundle {
    var localizedName: String {
        return localizedInfoDictionary?[kCFBundleNameKey as String] as? String ?? ""
    }

    var urlTypes: [URLType] {
        let dicts = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        return dicts.map { URLType($0) }
    }

    struct URLType {
        let name: String?
        let role: String?
        let schemes: [String]

        fileprivate init(_ plist: [String: Any]) {
            name = plist["CFBundleURLName"] as? String
            role = plist["CFBundleTypeRole"] as? String
            schemes = plist["CFBundleURLSchemes"] as? [String] ?? []
        }
    }
}

extension URLRequest {
    /**
     Sets a URL request's If-Modified-Since and If-None-Match headers appropriately, given the previous response's Last-Modified and Etag headers. No effort is done to test whether the response actually matches the request (by URL or otherwise).
     
     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.26 and http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.2.4
     */
    mutating func setCacheHeadersWithResponse(_ response: HTTPURLResponse) {
        if let etag = response.allHeaderFields["Etag"] as? String {
            setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        if let lastModified = response.allHeaderFields["Last-Modified"] as? String {
            setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
    }
}

extension Scanner {
    func scan(fromSet characterSet: NSCharacterSet) -> String? {
        var scanned: NSString?
        guard scanCharacters(from: characterSet as CharacterSet, into: &scanned) else { return nil }
        return scanned as String?
    }
    
    func scan(_ string: String) -> Bool {
        return scanString(string, into: nil)
    }
    
    func scanHex() -> UInt64? {
        var int: UInt64 = 0
        guard scanHexInt64(&int) else { return nil }
        return int
    }
}

extension NSString {
    var stringByCollapsingWhitespace: String {
        // Literal regex; should crash loudly if it can't be used.
        let regex = try! NSRegularExpression(pattern: "\\s+", options: [])
        return regex.stringByReplacingMatches(in: self as String, options: [], range: NSRange(0..<length), withTemplate: " ")
    }
}

extension String {
    mutating func collapseWhitespace() {
        let regex = try! NSRegularExpression(pattern: "\\s+", options: [])
        self = regex.stringByReplacingMatches(in: self as String, options: [], range: NSRange(startIndex..., in: self), withTemplate: " ")
    }
}

extension Timer {
    @discardableResult class func scheduledTimerWithInterval(_ interval: TimeInterval, repeats: Bool = false, handler: @escaping (Timer) -> Void) -> Timer {
        let timer = CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent() + interval, repeats ? interval : 0, 0, 0) { timer in
            handler(timer!)
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, CFRunLoopMode.commonModes)
        return timer!
    }
}
