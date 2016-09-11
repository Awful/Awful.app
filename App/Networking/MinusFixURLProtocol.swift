//  MinusFixURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// The AwfulMinusFixURLProtocol munges HTTP GET requests for i.minus.com so that they work as they do on the Forums proper.
final class MinusFixURLProtocol: URLProtocol {
    fileprivate var downloadTask: URLSessionDataTask?
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let
            URL = request.url,
            let host = URL.host
            else { return false }
        guard
            URL.scheme?.lowercased() == "http" &&
            request.httpMethod == "GET" &&
            host.lowercased().hasSuffix("i.minus.com") &&
            !(URLProtocol.property(forKey: didSetRefererForMinusKey, in: request) as? Bool ?? false)
            else { return false }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let request = (self.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        request.setValue(validReferer, forHTTPHeaderField: "Referer")
        URLProtocol.setProperty(true, forKey: didSetRefererForMinusKey, in: request)
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { [weak self] (data: Data?, response: URLResponse?, error: Error?) in
            defer { self?.downloadTask = nil }
            
            if let response = response {
                self?.client?.urlProtocol(self!, didReceive: response, cacheStoragePolicy: .allowed)
            }
            
            if let error = error {
                self?.client?.urlProtocol(self!, didFailWithError: error)
                return
            }
            
            if let data = data {
                self?.client?.urlProtocol(self!, didLoad: data)
            }
            
            self?.client?.urlProtocolDidFinishLoading(self!)
        }) 
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
