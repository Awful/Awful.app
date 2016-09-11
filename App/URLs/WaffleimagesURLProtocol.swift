//  WaffleimagesURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Restores the Waffleimages image host to its former glory.
final class WaffleimagesURLProtocol: URLProtocol {
    fileprivate var downloadTask: URLSessionTask?
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let URL = request.url else { return false }
        return randomwaffleURLForWaffleimagesURL(URL) != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        guard let URL = request.url, let randomwaffleURL = randomwaffleURLForWaffleimagesURL(URL) else { return request }
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        mutableRequest.url = randomwaffleURL
        return mutableRequest as URLRequest
    }
    
    override func startLoading() {
        let request = type(of: self).canonicalRequest(for: self.request)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            defer { self.downloadTask = nil }
            
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            }
            
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
        downloadTask = task
    }
    
    override func stopLoading() {
        downloadTask?.cancel()
        downloadTask = nil
    }
}

/**
    Turns a waffleimages.com URL into a randomwaffle.gbs.fm URL.
 
    Examples:
 
    * http://img.waffleimages.com/1df43ff210a2867f4e53faa40322e877f62897e4/t/DSC_0736.JPG
    * http://img.waffleimages.com/43bc914050a09db4e3df87289eb4b0e38e9e33eb/butter.jpg
    * http://img.waffleimages.com/images/7e/7e4178f6e4d086a7f418aa66cdffb64c32cd8c4c.jpg
 */
private func randomwaffleURLForWaffleimagesURL(_ url: URL) -> URL? {
    guard url.scheme?.lowercased().hasPrefix("http") == true else { return nil }
    guard let host = url.host, host.lowercased().hasSuffix("waffleimages.com") else { return nil }
    guard url.pathComponents.count >= 2 else { return nil }
    guard !url.pathExtension.isEmpty else { return nil }
    let hash: String
    if url.pathComponents.count == 4 && url.pathComponents[1].lowercased() == "images" {
        hash = (url.pathComponents[3] as NSString).deletingPathExtension
    } else {
        hash = url.pathComponents[1]
    }
    guard hash.utf8.count >= 2 else { return nil }
    guard let hashPrefix = String(hash.utf8[hash.utf8.startIndex..<hash.utf8.index(hash.utf8.startIndex, offsetBy: 2)]) else { return nil }
    var pathExtension = url.pathExtension
    if pathExtension.caseInsensitiveCompare("jpeg") == .orderedSame {
        pathExtension = "jpg"
    }
    
    // Pretty sure NSURLComponents init should always succeed from a URL.
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    components.host = "randomwaffle.gbs.fm"
    components.path = "/images/\(hashPrefix)/\(hash).\(pathExtension)"
    return components.url
}
