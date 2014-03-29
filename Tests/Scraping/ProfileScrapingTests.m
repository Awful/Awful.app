//  ProfileScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulProfileScraper.h"

@interface ProfileScrapingTests : AwfulScrapingTestCase

@end

@implementation ProfileScrapingTests

+ (Class)scraperClass
{
    return [AwfulProfileScraper class];
}

- (void)testWithAvatarAndText
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile"];
    AwfulUser *pokeyman = scraper.user;
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allUsers.count, (NSUInteger)1);
    XCTAssertEqualObjects(pokeyman.userID, @"106125");
    XCTAssertEqualObjects(pokeyman.username, @"pokeyman");
    XCTAssertNotEqual([pokeyman.customTitleHTML rangeOfString:@"play?"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([pokeyman.customTitleHTML rangeOfString:@"title-pokeyman"].location, (NSUInteger)NSNotFound);
    XCTAssertEqualObjects(pokeyman.icqName, @"1234");
    XCTAssertNil(pokeyman.aimName);
    XCTAssertNil(pokeyman.yahooName);
    XCTAssertNil(pokeyman.location);
    XCTAssertNil(pokeyman.interests);
    XCTAssertEqualObjects(pokeyman.gender, @"porpoise");
    XCTAssertEqual(pokeyman.postCount, 1954);
    XCTAssertEqualObjects(pokeyman.postRate, @"0.88");
}

- (void)testWithAvatarAndGangTag
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile2"];
    AwfulUser *ronald = scraper.user;
    XCTAssertEqualObjects(ronald.location, @"San Francisco");
    XCTAssertNotEqual([ronald.customTitleHTML rangeOfString:@"safs/titles"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([ronald.customTitleHTML rangeOfString:@"dd/68"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([ronald.customTitleHTML rangeOfString:@"01/df"].location, (NSUInteger)NSNotFound);
}

- (void)testWithFunkyText
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile3"];
    AwfulUser *rinkles = scraper.user;
    XCTAssertNotEqual([rinkles.customTitleHTML rangeOfString:@"<i>"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([rinkles.customTitleHTML rangeOfString:@"I'm getting at is"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([rinkles.customTitleHTML rangeOfString:@"safs/titles"].location, (NSUInteger)NSNotFound);
}

- (void)testWithNoAvatarOrTitle
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile4"];
    AwfulUser *crypticEdge = scraper.user;
    XCTAssertNotEqual([crypticEdge.customTitleHTML rangeOfString:@"<br"].location, (NSUInteger)NSNotFound);
}

- (void)testStupidNewbie
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile5"];
    AwfulUser *newbie = scraper.user;
    XCTAssertNotEqual([newbie.customTitleHTML rangeOfString:@"newbie.gif"].location, (NSUInteger)NSNotFound);
}

- (void)testWithGangTagButNoAvatar
{
    AwfulProfileScraper *scraper = [self scrapeFixtureNamed:@"profile6"];
    AwfulUser *gripper = scraper.user;
    XCTAssertNotEqual([gripper.customTitleHTML rangeOfString:@"i am winner"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([gripper.customTitleHTML rangeOfString:@"tccburnouts.png"].location, (NSUInteger)NSNotFound);
}

@end
