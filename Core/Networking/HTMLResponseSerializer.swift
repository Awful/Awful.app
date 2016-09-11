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
    
    override func responseObject(for response: URLResponse?, data: Data?) throws -> Any {
        guard let data = try super.responseObject(for: response, data: data) as? Data else { return HTMLDocument() }
        return HTMLDocument(data: data, contentTypeHeader: contentType(withResponse: response))
    }
}

private func contentType(withResponse rawResponse: URLResponse?) -> String? {
    guard let response = rawResponse as? HTTPURLResponse else { return nil }
    return response.allHeaderFields["Content-Type"] as? String
}
