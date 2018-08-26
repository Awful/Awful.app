//  PostimgOrgURLProtocol.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app


import Foundation

// Rewrites postimg.org links to postimg.cc to save some broken images.
class PostimgOrgURLProtocol: URLProtocol {
    fileprivate var downloadTask: URLSessionTask?
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let URL = request.url else { return false }
        return normalizeUrl(URL) != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        guard let URL = request.url, let url = normalizeUrl(URL) else { return request }
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        mutableRequest.url = url
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

private func normalizeUrl(_ url: URL) -> URL? {
    let hostSuffix = "postimg.org"
    let newHostSuffix = "postimg.cc"
    
    guard let host = url.host, host.lowercased().hasSuffix(hostSuffix) else { return nil }
    
    let newHost = String(host.dropLast(hostSuffix.count)) + newHostSuffix
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    components.host = newHost

    return components.url
}
