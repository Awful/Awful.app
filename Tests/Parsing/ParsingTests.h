//
//  ParsingTests.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
