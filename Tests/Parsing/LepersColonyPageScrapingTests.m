//  LepersColonyPageScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulParsingTestCase.h"
#import "AwfulLepersColonyPageScraper.h"

@interface LepersColonyPageScrapingTests : AwfulParsingTestCase

@end

@implementation LepersColonyPageScrapingTests

+ (Class)scraperClass
{
    return [AwfulLepersColonyPageScraper class];
}

- (void)testFirstPage
{
    NSArray *bans = [self scrapeFixtureNamed:@"banlist"];
    XCTAssertEqual(bans.count, (NSUInteger)50);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allUsers.count, (NSUInteger)71);
    NSArray *allPosts = [AwfulPost fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allPosts.count, (NSUInteger)46);
    
    AwfulBan *first = bans[0];
    XCTAssertEqual(first.punishment, AwfulPunishmentProbation);
    XCTAssertEqualObjects(first.post.postID, @"421665753");
    XCTAssertEqual(first.date.timeIntervalSince1970, 1384078200.);
    XCTAssertEqualObjects(first.user.username, @"Kheldragar");
    XCTAssertEqualObjects(first.user.userID, @"202925");
    XCTAssertNotEqual([first.reasonHTML rangeOfString:@"shitty as you"].location, NSNotFound);
    XCTAssertEqualObjects(first.requester.username, @"Ralp");
    XCTAssertEqualObjects(first.requester.userID, @"61644");
    XCTAssertEqualObjects(first.approver, first.requester);
}

@end
