//  HTTPRequestOperationManager.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking

/**
    Tunes up the defaults of its superclass:
 
    * Uses HTML request and response serializers.
    * Disables NSURLConnection's inexplicable built-in caching for HTTP GET respones that include no caching-related headers.
    * Immediately starts monitoring reachability.
 
    TODO: Only public so it appears in AwfulCore-Swift.h. Make internal once AwfulHTTPRequestOperationManager no longer needs an objc import.
 */
public final class HTTPRequestOperationManager: AFHTTPRequestOperationManager {
    override public init(baseURL: URL?) {
        super.init(baseURL: baseURL)
        
        requestSerializer = HTMLRequestSerializer()
        requestSerializer.stringEncoding = String.Encoding.windowsCP1252.rawValue
        
        responseSerializer = AFCompoundResponseSerializer.compoundSerializer(withResponseSerializers: [AFJSONRequestSerializer(), HTMLResponseSerializer()])
        
        reachabilityManager.startMonitoring()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func httpRequestOperation(with request: URLRequest, success: ((AFHTTPRequestOperation, Any) -> Void)? = nil, failure: ((AFHTTPRequestOperation, Error) -> Void)? = nil) -> AFHTTPRequestOperation {
        let operation = super.httpRequestOperation(with: request as URLRequest!, success: success, failure: failure)
        
        /*
            NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time.
 
            http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
 
            This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
         */
        guard request.httpMethod?.caseInsensitiveCompare("GET") == .orderedSame else { return operation }
        operation.setCacheResponseBlock { (connection, response) -> CachedURLResponse? in
            guard connection.currentRequest.cachePolicy == .useProtocolCachePolicy else { return response }
            guard let HTTPResponse = response.response as? HTTPURLResponse else { return response }
            let headers = HTTPResponse.allHeaderFields
            guard headers["Cache-Control"] == nil && headers["Expires"] == nil else { return response }
            
            print("\(#function) refusing to cache response to \(String(describing: request.url))")
            return nil
        }
        return operation
    }
}
