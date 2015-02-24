//  NSURL+QueryDictionary.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+QueryDictionary.h"
@import AwfulCore;

@implementation NSURL (QueryDictionary)

- (NSDictionary *)queryDictionary
{
    return AwfulCoreQueryDictionaryWithURL(self);
}

@end
