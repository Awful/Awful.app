//  ThreadListScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulThreadListScraper.h"

@interface ThreadListScrapingTests : AwfulScrapingTestCase

@end

@implementation ThreadListScrapingTests

+ (Class)scraperClass
{
    return [AwfulThreadListScraper class];
}

- (void)testAskTellThreadList
{
    AwfulThreadListScraper *scraper = [self scrapeFixtureNamed:@"showthread-asktell"];
    AwfulThread *stupidQuestions = scraper.threads.firstObject;
    AwfulThreadTag *askTag = stupidQuestions.secondaryThreadTag;
    XCTAssertEqualObjects(askTag.imageName, @"ama");
}

- (void)testBookmarkedThreadList
{
    AwfulThreadListScraper *scraper = [self scrapeFixtureNamed:@"bookmarkthreads"];;
    NSArray *scrapedThreads = scraper.threads;
    XCTAssertEqual(scrapedThreads.count, (NSUInteger)11);
    NSArray *allThreads = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(scrapedThreads.count, allThreads.count);
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allCategories.count, (NSUInteger)0);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allForums.count, (NSUInteger)0);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    NSArray *allUsernames = [[allUsers valueForKey:@"username"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(allUsernames, (@[ @"Choochacacko",
                                            @"csammis",
                                            @"Dreylad",
                                            @"escape artist",
                                            @"Ferg",
                                            @"I am in",
                                            @"pokeyman",
                                            @"Ranma4703",
                                            @"Salaminizer",
                                            @"Scaevolus",
                                            @"Sir Davey" ]));
    
    AwfulThread *wireThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                        matchingPredicateFormat:@"title BEGINSWITH 'The Wire'"];
    XCTAssertEqual(wireThread.starCategory, AwfulStarCategoryOrange);
    XCTAssertEqualObjects(wireThread.threadTag.imageName, @"tava-vintage");
    XCTAssertFalse(wireThread.sticky);
    XCTAssertEqualObjects(wireThread.title, @"The Wire: The Rewatch... and all the pieces matter.");
    XCTAssertEqual(wireThread.seenPosts, 435);
    XCTAssertEqualObjects(wireThread.author.username, @"escape artist");
    XCTAssertEqual(wireThread.totalReplies, 434);
    XCTAssertEqual(wireThread.numberOfVotes, (int16_t)0);
    XCTAssertEqual(wireThread.rating.doubleValue, 0.);
    XCTAssertEqual(wireThread.lastPostDate.timeIntervalSince1970, 1357964700.);
    XCTAssertEqualObjects(wireThread.lastPostAuthorName, @"MC Fruit Stripe");
    
    AwfulThread *CoCFAQ = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"title CONTAINS 'FAQ'"];
    XCTAssertEqual(CoCFAQ.starCategory, AwfulStarCategoryOrange);
    XCTAssertEqualObjects(CoCFAQ.threadTag.imageName, @"help");
    XCTAssertTrue(CoCFAQ.sticky);
    XCTAssertEqual(CoCFAQ.stickyIndex, 0);
    XCTAssertEqualObjects(CoCFAQ.title, @"Cavern of Cobol FAQ (Read this first)");
    XCTAssertEqual(CoCFAQ.seenPosts, 1);
    XCTAssertEqualObjects(CoCFAQ.author.username, @"Scaevolus");
    XCTAssertEqual(CoCFAQ.totalReplies, 0);
    XCTAssertEqual(CoCFAQ.rating.doubleValue, 0.);
    XCTAssertEqual(CoCFAQ.lastPostDate.timeIntervalSince1970, 1209381240.);
    XCTAssertEqualObjects(CoCFAQ.lastPostAuthorName, @"Scaevolus");
    
    AwfulThread *androidAppThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                              matchingPredicateFormat:@"author.username = 'Ferg'"];
    XCTAssertEqual(androidAppThread.starCategory, AwfulStarCategoryRed);
    XCTAssertEqual(androidAppThread.numberOfVotes, (int16_t)159);
    XCTAssertEqual(androidAppThread.rating.doubleValue, 4.79);
}

- (void)testDebateAndDiscussionThreadList
{
    AwfulThreadListScraper *scraper = [self scrapeFixtureNamed:@"forumdisplay"];
    NSArray *scrapedThreads = scraper.threads;
    XCTAssertEqual(scrapedThreads.count, (NSUInteger)40);
    NSArray *allThreads = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allThreads.count, scrapedThreads.count);
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allCategories.count, (NSUInteger)1);
    AwfulCategory *discussion = allCategories.firstObject;
    XCTAssertEqualObjects(discussion.name, @"Discussion");
    XCTAssertEqual(discussion.forums.count, (NSUInteger)1);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allForums.count, (NSUInteger)1);
    AwfulForum *debateAndDiscussion = allForums.firstObject;
    XCTAssertEqualObjects(debateAndDiscussion.name, @"Debate & Discussion");
    XCTAssertEqualObjects(debateAndDiscussion.forumID, @"46");
    NSSet *threadForums = [NSSet setWithArray:[allThreads valueForKey:@"forum"]];
    XCTAssertEqualObjects(threadForums, [NSSet setWithObject:debateAndDiscussion]);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    NSArray *allUsernames = [[allUsers valueForKey:@"username"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(allUsernames, (@[ @"a bad enough dude",
                                            @"Bedlamdan",
                                            @"BiggerBoat",
                                            @"blackguy32",
                                            @"CatCannons",
                                            @"Chamale",
                                            @"coolskillrex remix",
                                            @"Dreylad",
                                            @"evilweasel",
                                            @"Fire",
                                            @"Fluo",
                                            @"Fried Chicken",
                                            @"GAS CURES KIKES",
                                            @"hambeet",
                                            @"Helsing",
                                            @"Joementum",
                                            @"Landsknecht",
                                            @"Lascivious Sloth",
                                            @"lonelywurm",
                                            @"MiracleMouse",
                                            @"Pesmerga",
                                            @"Petey",
                                            @"Pobama",
                                            @"Salaminizer",
                                            @"showbiz_liz",
                                            @"Sir Kodiak",
                                            @"Solkanar512",
                                            @"Stefu",
                                            @"The Selling Wizard",
                                            @"TheOtherContraGuy",
                                            @"tonelok",
                                            @"UltimoDragonQuest",
                                            @"Vilerat",
                                            @"WYA",
                                            @"XyloJW",
                                            @"Zikan" ]));
    NSOrderedSet *tags = debateAndDiscussion.threadTags;
    XCTAssertEqual(tags.count, 106U);
    AwfulThreadTag *firstTag = tags.firstObject;
    XCTAssertEqualObjects(firstTag.threadTagID, @"357");
    XCTAssertEqualObjects(firstTag.imageName, @"dd-offmeds");
    AwfulThreadTag *lastTag = tags.lastObject;
    XCTAssertEqualObjects(lastTag.threadTagID, @"245");
    XCTAssertEqualObjects(lastTag.imageName, @"tcc-weed");
    
    AwfulThread *rulesThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                         matchingPredicateFormat:@"title CONTAINS 'Improved Rules'"];
    XCTAssertEqual(rulesThread.starCategory, AwfulStarCategoryNone);
    XCTAssertEqualObjects(rulesThread.threadTag.imageName, @"icon23-banme");
    XCTAssertTrue(rulesThread.sticky);
    XCTAssertNotEqual(rulesThread.stickyIndex, 0);
    XCTAssertEqualObjects(rulesThread.title, @"The Improved Rules of Debate and Discussion - New Update");
    XCTAssertEqual(rulesThread.seenPosts, 12);
    XCTAssertEqualObjects(rulesThread.author.username, @"tonelok");
    XCTAssertEqual(rulesThread.totalReplies, 11);
    XCTAssertEqual(rulesThread.numberOfVotes, (int16_t)0);
    XCTAssertEqual(rulesThread.rating.doubleValue, 0.);
    XCTAssertEqual(rulesThread.lastPostDate.timeIntervalSince1970, 1330198920.);
    XCTAssertEqualObjects(rulesThread.lastPostAuthorName, @"Xandu");
    
    AwfulThread *venezuelanThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                              matchingPredicateFormat:@"title BEGINSWITH 'Venezuelan'"];
    XCTAssertEqual(venezuelanThread.starCategory, AwfulStarCategoryNone);
    XCTAssertEqualObjects(venezuelanThread.threadTag.imageName, @"lf-marx");
    XCTAssertFalse(venezuelanThread.sticky);
    XCTAssertEqualObjects(venezuelanThread.title, @"Venezuelan elections");
    XCTAssertEqual(venezuelanThread.seenPosts, 0);
    XCTAssertEqualObjects(venezuelanThread.author.username, @"a bad enough dude");
    XCTAssertEqual(venezuelanThread.totalReplies, 410);
    XCTAssertEqual(venezuelanThread.numberOfVotes, (int16_t)0);
    XCTAssertEqual(venezuelanThread.rating.doubleValue, 0.);
    XCTAssertEqual(venezuelanThread.lastPostDate.timeIntervalSince1970, 1357082460.);
    XCTAssertEqualObjects(venezuelanThread.lastPostAuthorName, @"d3c0y2");
}

- (void)testSubforumHierarchy
{
    [self scrapeFixtureNamed:@"forumdisplay2"];
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allForums.count, (NSUInteger)2);
    NSArray *allForumNames = [[allForums valueForKey:@"name"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(allForumNames, (@[ @"Games", @"Let's Play!" ]));
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allCategories.count, (NSUInteger)1);
    AwfulCategory *discussion = allCategories.firstObject;
    XCTAssertEqual(discussion.forums.count, allForums.count);
    AwfulForum *games = [AwfulForum fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                 matchingPredicateFormat:@"name = 'Games'"];
    XCTAssertEqual(games.children.count, (NSUInteger)1);
    AwfulForum *letsPlay = games.children.firstObject;
    XCTAssertEqualObjects(letsPlay.name, @"Let's Play!");
}

@end
