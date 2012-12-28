//
//  ProfileTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"

@interface EditProfileTests : ParsingTests @end
@implementation EditProfileTests

+ (NSString *)fixtureFilename { return @"member.html"; }

- (void)testEditProfileInfo
{
    ProfileParsedInfo *profileInfo = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profileInfo.userID, @"106125", nil);
    STAssertEqualObjects(profileInfo.username, @"pokeyman", nil);
}

@end


@interface ViewProfileTests : ParsingTests @end
@implementation ViewProfileTests

+ (NSString *)fixtureFilename { return @"profile.html"; }

- (void)testViewProfileInfo
{
    ProfileParsedInfo *profileInfo = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profileInfo.username, @"pokeyman", nil);
    STAssertNotNil(profileInfo.avatar, nil);
    STAssertTrue([profileInfo.customTitle rangeOfString:@"play?"].location != NSNotFound, nil);
    STAssertEqualObjects(profileInfo.icqName, @"1234", nil);
    STAssertNil(profileInfo.aimName, nil);
    STAssertEquals(profileInfo.postCount, 1954, nil);
    STAssertTrue([profileInfo.postRate rangeOfString:@"0.88"].location == 0, nil);
    STAssertEqualObjects(profileInfo.gender, @"porpoise", nil);
}

@end
