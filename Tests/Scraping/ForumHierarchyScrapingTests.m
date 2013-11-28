//  ForumHierarchyScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulForumHierarchyScraper.h"

@interface ForumHierarchyScrapingTests : AwfulScrapingTestCase

@end

@implementation ForumHierarchyScrapingTests

+ (Class)scraperClass
{
    return [AwfulForumHierarchyScraper class];
}

- (void)testHierarchy
{
    NSArray *categories = [self scrapeFixtureNamed:@"forumdisplay"];
    NSArray *categoryNames = [[categories valueForKey:@"name"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(categoryNames, (@[
                                            @"Archives",
                                            @"Discussion",
                                            @"Main",
                                            @"The Community",
                                            @"The Finer Arts",
                                            ]));
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(categories.count, allCategories.count);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allForums.count, (NSUInteger)66);
    
    AwfulForum *ENBullshit = [AwfulForum fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                      matchingPredicateFormat:@"name BEGINSWITH 'E/N'"];
    XCTAssertEqualObjects(ENBullshit.forumID, @"214");
    XCTAssertEqualObjects(ENBullshit.name, @"E/N Bullshit");
    AwfulForum *GBS = ENBullshit.parentForum;
    XCTAssertEqualObjects(GBS.forumID, @"1");
    XCTAssertEqualObjects(GBS.name, @"General Bullshit");
    AwfulCategory *main = GBS.category;
    XCTAssertEqualObjects(main.categoryID, @"48");
    XCTAssertEqualObjects(main.name, @"Main");
    XCTAssertEqualObjects(ENBullshit.category, main);
    
    AwfulForum *gameRoom = [AwfulForum fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"forumID = '103'"];
    XCTAssertEqualObjects(gameRoom.name, @"The Game Room");
    AwfulForum *traditionalGames = gameRoom.parentForum;
    XCTAssertEqualObjects(traditionalGames.forumID, @"234");
    XCTAssertEqualObjects(traditionalGames.name, @"Traditional Games");
    AwfulForum *games = traditionalGames.parentForum;
    XCTAssertEqualObjects(games.forumID, @"44");
    XCTAssertEqualObjects(games.name, @"Games");
    AwfulCategory *discussion = games.category;
    XCTAssertEqualObjects(discussion.categoryID, @"51");
    XCTAssertEqualObjects(discussion.name, @"Discussion");
    XCTAssertEqualObjects(traditionalGames.category, discussion);
    XCTAssertEqualObjects(gameRoom.category, discussion);
}

@end
