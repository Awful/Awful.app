//  WaffleimagesURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Restores the Waffleimages image host to its former glory.
final class WaffleimagesURLProtocol: NSURLProtocol {
    private var downloadTask: NSURLSessionTask?
    
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        guard let URL = request.URL else { return false }
        return randomwaffleURLForWaffleimagesURL(URL) != nil
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        guard let URL = request.URL, let randomwaffleURL = randomwaffleURLForWaffleimagesURL(URL) else { return request }
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.URL = randomwaffleURL
        return mutableRequest
    }
    
    override func startLoading() {
        let request = type(of: self).canonicalRequestForRequest(self.request)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
            defer { self.downloadTask = nil }
            
            if let response = response {
                self.client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .Allowed)
            }
            
            if let error = error {
                self.client?.URLProtocol(self, didFailWithError: error)
                return
            }
            
            if let data = data {
                self.client?.URLProtocol(self, didLoadData: data)
            }
            
            self.client?.URLProtocolDidFinishLoading(self)
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
private func randomwaffleURLForWaffleimagesURL(URL: NSURL) -> NSURL? {
    guard URL.scheme.lowercaseString.hasPrefix("http") else { return nil }
    guard let host = URL.host , host.lowercaseString.hasSuffix("waffleimages.com") else { return nil }
    guard let pathComponents = URL.pathComponents , pathComponents.count >= 2 else { return nil }
    guard var pathExtension = URL.pathExtension , !pathExtension.isEmpty else { return nil }
    let hash: String
    if pathComponents.count == 4 && pathComponents[1].lowercaseString == "images" {
        hash = (pathComponents[3] as NSString).stringByDeletingPathExtension
    } else {
        hash = pathComponents[1]
    }
    guard hash.utf8.count >= 2 else { return nil }
    guard let hashPrefix = String(hash.utf8[hash.utf8.startIndex..<hash.utf8.startIndex.advancedBy(2)]) else { return nil }
    if pathExtension.caseInsensitiveCompare("jpeg") == .OrderedSame {
        pathExtension = "jpg"
    }
    
    // Pretty sure NSURLComponents init should always succeed from a URL.
    let components = NSURLComponents(string: URL.absoluteString)!
    components.host = "randomwaffle.gbs.fm"
    components.path = "/images/\(hashPrefix)/\(hash).\(pathExtension)"
    return components.URL
}
