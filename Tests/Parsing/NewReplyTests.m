//
//  NewReplyTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

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
    STAssertEqualObjects(info.formkey, @"0253d85a945b60daa0165f718df82b8a", nil);
    STAssertEqualObjects(info.formCookie, @"ea89ff590b8c", nil);
    STAssertEqualObjects(info.bookmark, @"yes", nil);
}

@end
