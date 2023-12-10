//  CachebustingSessionDelegate.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Changes the default caching policy for HTTP responses that have no cache headers to "do not cache".
final class CachebustingSessionDelegate: NSObject, URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse
    ) async -> CachedURLResponse? {
        /*
         NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time. I haven't checked but I'm guessing URLSession works the same.

         http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html

         This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
         */
        if let request = dataTask.currentRequest,
           request.httpMethod?.uppercased() == "GET",
           request.cachePolicy == .useProtocolCachePolicy,
           let httpResponse = proposedResponse.response as? HTTPURLResponse,
           case let headers = httpResponse.allHeaderFields,
           headers["Cache-Control"] == nil,
           headers["Expires"] == nil
        {
            return nil
        }
        
        return proposedResponse
    }
}
