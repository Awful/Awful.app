//  NSURLQueryDictionary.h
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/// Returns a (remember, unordered!) dictionary of the URL's query string.
NSDictionary * AwfulCoreQueryDictionaryWithURL(NSURL *URL);
