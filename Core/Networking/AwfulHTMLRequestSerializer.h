//  AwfulHTMLRequestSerializer.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import AFNetworking;

/**
 * An AwfulHTMLRequestSerializer ensures parameter values are within its string encoding by turning any outside characters into decimal HTML entities.
 */
@interface AwfulHTMLRequestSerializer : AFHTTPRequestSerializer

@end
