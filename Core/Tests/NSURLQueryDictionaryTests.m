//  NSURLQueryDictionaryTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import XCTest;
#import "NSURLQueryDictionary.h"

@interface NSURLQueryDictionaryTests : XCTestCase

@end

@implementation NSURLQueryDictionaryTests

- (void)testSome
{
    NSURL *URL = [NSURL URLWithString:@"?g=hello&what=updog"];
    XCTAssertEqualObjects(QueryDictionaryWithURL(URL), (@{ @"g": @"hello", @"what": @"updog" }));
}

- (void)testOne
{
    NSURL *URL = [NSURL URLWithString:@"?sam=iam"];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"sam": @"iam" }));
}

- (void)testOneSkippingOne
{
    NSURL *URL = [NSURL URLWithString:@"?&howdy=maam"];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"howdy": @"maam" }));
}

- (void)testEmptyValue
{
    NSURL *URL = [NSURL URLWithString:@"?whodat="];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"whodat": @"" }));
}

- (void)testEmptyKey
{
    NSURL *URL = [NSURL URLWithString:@"?=ahoy"];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"": @"ahoy" }));
}

- (void)testNoEquals
{
    NSURL *URL = [NSURL URLWithString:@"?hooray"];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"hooray": @"" }));
}

- (void)testManyNoEquals
{
    NSURL *URL = [NSURL URLWithString:@"?reach&for&the&sky"];
    XCTAssertEqualObjects(URL.queryDictionary, (@{ @"reach": @"", @"for": @"", @"the": @"", @"sky": @"" }));
}

@end
