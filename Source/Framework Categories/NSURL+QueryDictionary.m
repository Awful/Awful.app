//  NSURL+QueryDictionary.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+QueryDictionary.h"

@implementation NSURL (QueryDictionary)

- (NSDictionary *)queryDictionary
{
    NSMutableDictionary *queryDictionary = [NSMutableDictionary new];
    for (NSString *pair in [self.query componentsSeparatedByString:@"&"]) {
        if (pair.length == 0) continue;
        NSArray *keyAndValue = [pair componentsSeparatedByString:@"="];
        NSString *value = @"";
        if (keyAndValue.count > 1) value = keyAndValue[1];
        queryDictionary[keyAndValue[0]] = value;
    }
    return queryDictionary;
}

@end
