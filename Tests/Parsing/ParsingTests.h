//
//  ParsingTests.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "AwfulParsing.h"

@interface ParsingTests : SenTestCase

@property (readonly, copy, nonatomic) NSData *fixture;

+ (NSString *)fixtureFilename;

@end

#define STAssertStringContainsSubstringOnce(s, sub, ...) do { \
    STAssertNotNil(s, __VA_ARGS__); \
    NSRange __a = [s rangeOfString:sub]; \
    STAssertTrue(__a.location != NSNotFound, __VA_ARGS__); \
    NSRange __b = [s rangeOfString:sub options:NSBackwardsSearch]; \
    STAssertTrue(NSEqualRanges(__a, __b), __VA_ARGS__); \
} while (0)


#define STAssertStringDoesNotContain(s, sub, ...) \
    STAssertTrue([s rangeOfString:sub].location == NSNotFound, __VA_ARGS__)
