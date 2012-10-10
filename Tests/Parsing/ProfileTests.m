//
//  ProfileTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"
#import "AwfulParsing.h"

@interface ProfileTests : ParsingTests

@end


@implementation ProfileTests

+ (NSString *)fixtureFilename
{
    return @"member.html";
}

- (void)testUserInfo
{
    ParsedUserInfo *userInfo = [[ParsedUserInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(userInfo.userID, @"106125", nil);
    STAssertEqualObjects(userInfo.username, @"pokeyman", nil);
}

@end
