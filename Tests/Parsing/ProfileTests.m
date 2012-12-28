//
//  ProfileTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"

@interface ProfileTests : ParsingTests

@end


@implementation ProfileTests

+ (NSString *)fixtureFilename
{
    return @"member.html";
}

- (void)testEditProfileInfo
{
    ProfileParsedInfo *profileInfo = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profileInfo.userID, @"106125", nil);
    STAssertEqualObjects(profileInfo.username, @"pokeyman", nil);
}

@end
