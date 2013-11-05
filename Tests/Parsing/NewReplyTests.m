//  NewReplyTests.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ParsingTests.h"

@interface NewReplyTests : ParsingTests

@end


@implementation NewReplyTests

+ (NSString *)fixtureFilename
{
    return @"newreply.html";
}

- (void)testFormValues
{
    ReplyFormParsedInfo *info = [[ReplyFormParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(info.formkey, @"0253d85a945b60daa0165f718df82b8a");
    XCTAssertEqualObjects(info.formCookie, @"80c74b48f557");
    XCTAssertEqualObjects(info.bookmark, @"yes");
}

@end
