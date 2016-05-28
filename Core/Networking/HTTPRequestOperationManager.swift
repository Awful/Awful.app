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
    override init(baseURL: NSURL?) {
        super.init(baseURL: baseURL)
        
        requestSerializer = HTMLRequestSerializer()
        requestSerializer.stringEncoding = NSWindowsCP1252StringEncoding
        
        responseSerializer = AFCompoundResponseSerializer.compoundSerializerWithResponseSerializers([AFJSONRequestSerializer(), HTMLResponseSerializer()])
        
        reachabilityManager.startMonitoring()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func HTTPRequestOperationWithRequest(request: NSURLRequest!, success: ((AFHTTPRequestOperation!, AnyObject!) -> Void)!, failure: ((AFHTTPRequestOperation!, NSError!) -> Void)!) -> AFHTTPRequestOperation! {
        let operation = super.HTTPRequestOperationWithRequest(request, success: success, failure: failure)
        
        /*
            NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time.
 
            http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
 
            This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
         */
        guard request.HTTPMethod?.caseInsensitiveCompare("GET") == .OrderedSame else { return operation }
        operation.setCacheResponseBlock { (connection, response) -> NSCachedURLResponse! in
            guard connection.currentRequest.cachePolicy == .UseProtocolCachePolicy else { return response }
            guard let HTTPResponse = response.response as? NSHTTPURLResponse else { return response }
            let headers = HTTPResponse.allHeaderFields
            guard headers["Cache-Control"] == nil && headers["Expires"] == nil else { return response }
            
            print("\(#function) refusing to cache response to \(request.URL)")
            return nil
        }
        return operation
    }
}
