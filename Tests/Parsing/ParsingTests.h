//  ParsingTests.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <XCTest/XCTest.h>
#import "AwfulParsing.h"

@interface ParsingTests : XCTestCase

@property (readonly, copy, nonatomic) NSData *fixture;

+ (NSString *)fixtureFilename;

@end

#define AwfulAssertStringContainsSubstringOnce(s, sub, ...) do { \
    XCTAssertNotNil(s, ##__VA_ARGS__); \
    NSRange __a = [s rangeOfString:sub]; \
    XCTAssertTrue(__a.location != NSNotFound, ##__VA_ARGS__); \
    NSRange __b = [s rangeOfString:sub options:NSBackwardsSearch]; \
    XCTAssertTrue(NSEqualRanges(__a, __b), ##__VA_ARGS__); \
} while (0)


#define AwfulAssertStringDoesNotContain(s, sub, ...) \
    XCTAssertTrue([s rangeOfString:sub].location == NSNotFound, ##__VA_ARGS__)
