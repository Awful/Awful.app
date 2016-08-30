//  MinusFixURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// The AwfulMinusFixURLProtocol munges HTTP GET requests for i.minus.com so that they work as they do on the Forums proper.
final class MinusFixURLProtocol: NSURLProtocol {
    private var downloadTask: NSURLSessionDataTask?
    
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        guard let
            URL = request.URL,
            let host = URL.host
            else { return false }
        guard
            URL.scheme.lowercaseString == "http" &&
            request.HTTPMethod == "GET" &&
            host.lowercaseString.hasSuffix("i.minus.com") &&
            !(NSURLProtocol.propertyForKey(didSetRefererForMinusKey, inRequest: request) as? Bool ?? false)
            else { return false }
        return true
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override func startLoading() {
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.setValue(validReferer, forHTTPHeaderField: "Referer")
        NSURLProtocol.setProperty(true, forKey: didSetRefererForMinusKey, inRequest: mutableRequest)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(mutableRequest) { [weak self] (data: NSData?, response: NSURLResponse?, error: NSError?) in
            defer { self?.downloadTask = nil }
            
            if let response = response {
                self?.client?.URLProtocol(self!, didReceiveResponse: response, cacheStoragePolicy: .Allowed)
            }
            
            if let error = error {
                self?.client?.URLProtocol(self!, didFailWithError: error)
                return
            }
            
            if let data = data {
                self?.client?.URLProtocol(self!, didLoadData: data)
            }
            
            self?.client?.URLProtocolDidFinishLoading(self!)
        }
        downloadTask = task
        task.resume()
    }
    
    override func stopLoading() {
        downloadTask?.cancel()
        downloadTask = nil
    }
}

private let didSetRefererForMinusKey = "com.awfulapp.Awful.DidSetRefererForMinus"
private let validReferer = "http://forums.somethingawful.com/"
