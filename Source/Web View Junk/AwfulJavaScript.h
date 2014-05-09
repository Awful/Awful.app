//  AwfulJavaScript.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/**
 * Returns concatenated JavaScript files from the main bundle, or nil if an error occurs.
 *
 * @param filenames NSStrings of names of JavaScript resources, extension included.
 * @param error     If non-nil, is filled with an NSError on failure. The userInfo will have a value for NSURLErrorKey indicating which resource failed to load.
 */
extern NSString * LoadJavaScriptResources(NSArray *filenames, NSError * __autoreleasing *error);
