//  HTMLResponseSerializer.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking

/// Turns HTTP responses into HTML documents.
final class HTMLResponseSerializer: AFHTTPResponseSerializer {
    override init() {
        super.init()
        
        acceptableContentTypes = ["text/html", "application/xhtml+xml"]
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func responseObjectForResponse(response: NSURLResponse?, data unvalidatedData: NSData?) throws -> AnyObject {
        guard let data = try super.responseObjectForResponse(response, data: unvalidatedData) as? NSData else { return HTMLDocument() }
        return HTMLDocument(data: data, contentTypeHeader: contentType(withResponse: response))
    }
}

private func contentType(withResponse rawResponse: NSURLResponse?) -> String? {
    guard let response = rawResponse as? NSHTTPURLResponse else { return nil }
    return response.allHeaderFields["Content-Type"] as? String
}
