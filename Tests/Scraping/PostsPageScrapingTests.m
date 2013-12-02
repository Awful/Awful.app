//  PostsPageScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulPostsPageScraper.h"

@interface PostsPageScrapingTests : AwfulScrapingTestCase

@end

@implementation PostsPageScrapingTests

+ (Class)scraperClass
{
    return [AwfulPostsPageScraper class];
}

- (void)testCanadianPoliticsThread
{
    NSArray *posts = [self scrapeFixtureNamed:@"showthread"];
    XCTAssertEqual(posts.count, (NSUInteger)40);
    NSArray *allThreads = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allThreads.count, (NSUInteger)1);
    AwfulThread *canpoliThread = allThreads.firstObject;
    XCTAssertEqualObjects(canpoliThread.threadID, @"3507451");
    XCTAssertEqualObjects(canpoliThread.title, @"Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe");
    XCTAssertFalse(canpoliThread.closed);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allForums.count, (NSUInteger)1);
    AwfulForum *forum = canpoliThread.forum;
    XCTAssertEqualObjects(forum.name, @"Debate & Discussion");
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allCategories.count, (NSUInteger)1);
    AwfulCategory *category = allCategories.firstObject;
    XCTAssertEqualObjects(category.name, @"Discussion");
    
    AwfulPost *firstPost = posts[0];
    XCTAssertEqualObjects(firstPost.postID, @"407741839");
    XCTAssertNotEqual([firstPost.innerHTML rangeOfString:@"more I think about it"].location, NSNotFound);
    XCTAssertEqual(firstPost.threadIndex, 161);
    XCTAssertEqual(firstPost.postDate.timeIntervalSince1970, 1348139760.);
    XCTAssertTrue(firstPost.beenSeen);
    XCTAssertFalse(firstPost.editable);
    XCTAssertEqualObjects(firstPost.thread, canpoliThread);
    AwfulUser *majuju = firstPost.author;
    XCTAssertEqualObjects(majuju.username, @"Majuju");
    XCTAssertEqualObjects(majuju.userID, @"108110");
    XCTAssertTrue(majuju.canReceivePrivateMessages);
    XCTAssertEqual(majuju.regdate.timeIntervalSince1970, 1167350400.);
    XCTAssertNotEqual([majuju.customTitleHTML rangeOfString:@"AAA"].location, NSNotFound);
    
    AwfulPost *accentAiguPost = posts[10];
    XCTAssertEqualObjects(accentAiguPost.postID, @"407751664");
    XCTAssertNotEqual([accentAiguPost.innerHTML rangeOfString:@"Québec"].location, NSNotFound);
    
    AwfulPost *opPost = posts[12];
    XCTAssertEqualObjects(opPost.postID, @"407751956");
    XCTAssertEqualObjects(opPost.author.username, @"Dreylad");
    XCTAssertEqualObjects(opPost.author, canpoliThread.author);
    
    AwfulPost *adminPost = posts[14];
    XCTAssertEqualObjects(adminPost.postID, @"407753032");
    XCTAssertEqualObjects(adminPost.author.username, @"angerbot");
    XCTAssertTrue(adminPost.author.administrator);
    XCTAssertFalse(adminPost.author.moderator);
    
    AwfulPost *lastPost = posts.lastObject;
    XCTAssertEqualObjects(lastPost.postID, @"407769816");
    XCTAssertEqual(lastPost.threadIndex, 200);
}

- (void)testWeirdSizeTags
{
    // Some posts have a tag that looks like `<size:8>`. Once upon a time, all subsequent posts went missing. In this fixture, Ganker's custom title has a `<size:8>` tag.
    NSArray *posts = [self scrapeFixtureNamed:@"showthread2"];
    XCTAssertEqual(posts.count, (NSUInteger)40);
    AwfulPost *ganker = posts[24];
    XCTAssertEqualObjects(ganker.author.username, @"Ganker");
    XCTAssertNotEqual([ganker.author.customTitleHTML rangeOfString:@"forced meme"].location, NSNotFound);
    AwfulPost *brylcreem = posts[25];
    XCTAssertEqualObjects(brylcreem.author.username, @"brylcreem");
}

- (void)testFYADThreadIndex
{
    NSArray *posts = [self scrapeFixtureNamed:@"showthread-fyad"];
    XCTAssertEqual(posts.count, (NSUInteger)10);
    AwfulPost *last = posts.lastObject;
    XCTAssertEqual(last.page, (NSInteger)2);
}

- (void)testLastPage
{
    [self scrapeFixtureNamed:@"showthread-last"];
    AwfulThread *thread = [[AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext] lastObject];
    XCTAssertEqualObjects(thread.lastPostAuthorName, @"Ashmole");
    XCTAssertEqual(thread.lastPostDate.timeIntervalSince1970, 1357586460.0);
}

@end
