//  URLRequest+.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

// MARK: Set cache headers

public extension URLRequest {
    /**
     Sets a URL request's If-Modified-Since and If-None-Match headers appropriately, given the previous response's Last-Modified and Etag headers. No effort is done to test whether the response actually matches the request (by URL or otherwise).

     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.26 and http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.2.4
     */
    mutating func setCacheHeaders(_ response: HTTPURLResponse) {
        if let etag = response.allHeaderFields["Etag"] as? String {
            setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        if let lastModified = response.allHeaderFields["Last-Modified"] as? String {
            setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
    }
}
