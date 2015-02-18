//  NSURLQueryDictionary.m
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURLQueryDictionary.h"

NSDictionary * AwfulCoreQueryDictionaryWithURL(NSURL *URL)
{
    NSMutableDictionary *queryDictionary = [NSMutableDictionary new];
    for (NSString *pair in [URL.query componentsSeparatedByString:@"&"]) {
        if (pair.length == 0) continue;
        NSArray *keyAndValue = [pair componentsSeparatedByString:@"="];
        NSString *value = @"";
        if (keyAndValue.count > 1) value = keyAndValue[1];
        queryDictionary[keyAndValue[0]] = value;
    }
    return queryDictionary;
}
