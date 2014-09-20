//  CacheHeaderCalculations.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 * Sets a URL request's If-Modified-Since and Etag headers appropriately, given the previous response.
 *
 * See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.26 and http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.2.4
 */
extern void SetCacheHeadersForRequest(NSMutableURLRequest *request, NSHTTPURLResponse *response);
