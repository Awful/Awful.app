//  AwfulHTTPRequestOperationManager.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AFNetworking/AFNetworking.h>

/**
 * An AwfulHTTPRequestOperationManager tunes up the defaults of its superclass:
 *
 * * Uses HTML request and response serializers. String encodings are set to win-1252 (with a response fallback to latin1).
 * * Disables NSURLConnection's inexplicable built-in caching for HTTP GET respones that include no caching-related headers.
 * * Immediately starts monitoring reachability.
 */
@interface AwfulHTTPRequestOperationManager : AFHTTPRequestOperationManager

@end
