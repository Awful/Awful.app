//
//  NSURL+QueryDictionary.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSURL+QueryDictionary.h"

@implementation NSURL (QueryDictionary)

- (NSDictionary *)queryDictionary
{
    NSMutableDictionary *queryDictionary = [NSMutableDictionary new];
    for (NSString *pair in [[self query] componentsSeparatedByString:@"&"]) {
        NSArray *keyAndValue = [pair componentsSeparatedByString:@"="];
        queryDictionary[keyAndValue[0]] = keyAndValue[1];
    }
    return queryDictionary;
}

@end
