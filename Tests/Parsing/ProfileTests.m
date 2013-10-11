//  ProfileTests.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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


@interface ViewProfileWithAvatarAndTextTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndTextTests

+ (NSString *)fixtureFilename { return @"profile.html"; }

- (void)testViewAvatarAndText
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"pokeyman", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"play?", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"title-pokeyman", nil);
    STAssertEqualObjects(profile.icqName, @"1234", nil);
    STAssertNil(profile.aimName, nil);
    STAssertEquals(profile.postCount, 1954, nil);
    STAssertTrue([profile.postRate rangeOfString:@"0.88"].location == 0, nil);
    STAssertEqualObjects(profile.gender, @"porpoise", nil);
}

@end


@interface ViewProfileWithAvatarAndGangTagTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndGangTagTests

+ (NSString *)fixtureFilename { return @"profile2.html"; }

- (void)testViewAvatarAndGangTag
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"Ronald Raiden", nil);
    STAssertEqualObjects(profile.location, @"San Francisco", nil);
    STAssertTrue([profile.customTitleHTML rangeOfString:@"safs/titles"].length > 0, nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"dd/68", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"01/df", nil);
}

@end


@interface ViewProfileWithAvatarAndFunkyTextTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndFunkyTextTests

+ (NSString *)fixtureFilename { return @"profile3.html"; }

- (void)testViewAvatarAndFunkyText
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"Rinkles", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"<i>", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"I'm getting at is", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"safs/titles", nil);
}

@end

@interface ViewProfileWithNoAvatarOrTitleTests : ParsingTests @end
@implementation ViewProfileWithNoAvatarOrTitleTests

+ (NSString *)fixtureFilename { return @"profile4.html"; }

- (void)testViewNoAvatarOrTitle
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"Cryptic Edge", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"<br", nil);
}

@end


@interface ViewStupidNewbieProfileTests : ParsingTests @end
@implementation ViewStupidNewbieProfileTests

+ (NSString *)fixtureFilename { return @"profile5.html"; }

- (void)testViewStupidNewbie
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"Grim Up North", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"newbie.gif", nil);
}

@end


@interface ViewProfileWithTitleAndGangTagAndNoAvatar : ParsingTests @end
@implementation ViewProfileWithTitleAndGangTagAndNoAvatar

+ (NSString *)fixtureFilename { return @"profile6.html"; }

- (void)testViewTitleAndGangTagAndNoAvatar
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(profile.username, @"The Gripper", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"i am winner", nil);
    STAssertStringContainsSubstringOnce(profile.customTitleHTML, @"tccburnouts.png", nil);
}

@end
