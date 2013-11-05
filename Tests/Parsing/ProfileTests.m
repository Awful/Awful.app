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
    XCTAssertEqualObjects(profileInfo.userID, @"106125");
    XCTAssertEqualObjects(profileInfo.username, @"pokeyman");
}

@end


@interface ViewProfileWithAvatarAndTextTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndTextTests

+ (NSString *)fixtureFilename { return @"profile.html"; }

- (void)testViewAvatarAndText
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"pokeyman");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"play?");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"title-pokeyman");
    XCTAssertEqualObjects(profile.icqName, @"1234");
    XCTAssertNil(profile.aimName);
    XCTAssertEqual(profile.postCount, 1954);
    XCTAssertTrue([profile.postRate rangeOfString:@"0.88"].location == 0);
    XCTAssertEqualObjects(profile.gender, @"porpoise");
}

@end


@interface ViewProfileWithAvatarAndGangTagTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndGangTagTests

+ (NSString *)fixtureFilename { return @"profile2.html"; }

- (void)testViewAvatarAndGangTag
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"Ronald Raiden");
    XCTAssertEqualObjects(profile.location, @"San Francisco");
    XCTAssertTrue([profile.customTitleHTML rangeOfString:@"safs/titles"].length > 0);
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"dd/68");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"01/df");
}

@end


@interface ViewProfileWithAvatarAndFunkyTextTests : ParsingTests @end
@implementation ViewProfileWithAvatarAndFunkyTextTests

+ (NSString *)fixtureFilename { return @"profile3.html"; }

- (void)testViewAvatarAndFunkyText
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"Rinkles");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"<i>");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"I'm getting at is");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"safs/titles");
}

@end

@interface ViewProfileWithNoAvatarOrTitleTests : ParsingTests @end
@implementation ViewProfileWithNoAvatarOrTitleTests

+ (NSString *)fixtureFilename { return @"profile4.html"; }

- (void)testViewNoAvatarOrTitle
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"Cryptic Edge");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"<br");
}

@end


@interface ViewStupidNewbieProfileTests : ParsingTests @end
@implementation ViewStupidNewbieProfileTests

+ (NSString *)fixtureFilename { return @"profile5.html"; }

- (void)testViewStupidNewbie
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"Grim Up North");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"newbie.gif");
}

@end


@interface ViewProfileWithTitleAndGangTagAndNoAvatar : ParsingTests @end
@implementation ViewProfileWithTitleAndGangTagAndNoAvatar

+ (NSString *)fixtureFilename { return @"profile6.html"; }

- (void)testViewTitleAndGangTagAndNoAvatar
{
    ProfileParsedInfo *profile = [[ProfileParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(profile.username, @"The Gripper");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"i am winner");
    AwfulAssertStringContainsSubstringOnce(profile.customTitleHTML, @"tccburnouts.png");
}

@end
