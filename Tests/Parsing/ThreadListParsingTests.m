//  ThreadListParsingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <XCTest/XCTest.h>
#import "AwfulDataStack.h"
#import "AwfulThreadListScraper.h"
#import <HTMLReader/HTMLReader.h>

@interface ThreadListParsingTests : XCTestCase

@property (strong, nonatomic) AwfulDataStack *dataStack;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation ThreadListParsingTests

- (AwfulDataStack *)dataStack
{
    if (_dataStack) return _dataStack;
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Awful" withExtension:@"momd"];
    _dataStack = [[AwfulDataStack alloc] initWithStoreURL:nil modelURL:modelURL];
    return _dataStack;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return self.dataStack.managedObjectContext;
}

- (id)scrapeFixtureNamed:(NSString *)fixtureName
{
    NSString *fixturePath = [@"Fixtures" stringByAppendingPathComponent:fixtureName];
    NSURL *fixtureURL = [[NSBundle bundleForClass:[self class]] URLForResource:fixturePath withExtension:@"html"];
    NSError *error;
    NSString *fixtureHTML = [NSString stringWithContentsOfURL:fixtureURL encoding:NSWindowsCP1252StringEncoding error:&error];
    XCTAssertNotNil(fixtureHTML, @"error loading fixture from %@: %@", fixtureURL, error);
    HTMLDocument *document = [HTMLDocument documentWithString:fixtureHTML];
    AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
    NSArray *scrapedThreads = [scraper scrapeDocument:document
                                              fromURL:fixtureURL
                             intoManagedObjectContext:self.managedObjectContext
                                                error:&error];
    XCTAssertNotNil(scrapedThreads, @"error scraping threads: %@", error);
    return scrapedThreads;
}

- (void)setUp
{
    [super setUp];
    
    // The scraper uses the default time zone. To make the test repeatable, we set a known time zone.
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
}

- (void)tearDown
{
    [_dataStack deleteStoreAndResetStack];
    [super tearDown];
}

- (void)testBookmarkedThreadList
{
    NSArray *scrapedThreads = [self scrapeFixtureNamed:@"bookmarkthreads"];
    XCTAssertTrue(scrapedThreads.count == 11);
    NSArray *allThreads = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(scrapedThreads.count, allThreads.count);
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertTrue(allCategories.count == 0);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertTrue(allForums.count == 0);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    NSArray *allUsernames = [[allUsers valueForKey:@"username"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(allUsernames, (@[
                                           @"Choochacacko",
                                           @"csammis",
                                           @"Dreylad",
                                           @"escape artist",
                                           @"Ferg",
                                           @"I am in",
                                           @"pokeyman",
                                           @"Ranma4703",
                                           @"Salaminizer",
                                           @"Scaevolus",
                                           @"Sir Davey",
                                           ]));
    
    AwfulThread *wireThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                        matchingPredicateFormat:@"title BEGINSWITH 'The Wire'"];
    XCTAssertEqual(wireThread.starCategory, AwfulStarCategoryOrange);
    XCTAssertEqualObjects(wireThread.threadTagURL.lastPathComponent, @"tava-vintage.gif");
    XCTAssertFalse(wireThread.sticky);
    XCTAssertEqualObjects(wireThread.title, @"The Wire: The Rewatch... and all the pieces matter.");
    XCTAssertTrue(wireThread.seenPosts == 435);
    XCTAssertEqualObjects(wireThread.author.username, @"escape artist");
    XCTAssertTrue(wireThread.totalReplies == 434);
    XCTAssertTrue(wireThread.numberOfVotes == 0);
    XCTAssertTrue(wireThread.rating.doubleValue == 0);
    XCTAssertTrue(wireThread.lastPostDate.timeIntervalSince1970 == 1357964700);
    XCTAssertEqualObjects(wireThread.lastPostAuthorName, @"MC Fruit Stripe");
    
    AwfulThread *CoCFAQ = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"title CONTAINS 'FAQ'"];
    XCTAssertEqual(CoCFAQ.starCategory, AwfulStarCategoryOrange);
    XCTAssertEqualObjects(CoCFAQ.threadTagURL.lastPathComponent, @"help.png");
    XCTAssertTrue(CoCFAQ.sticky);
    XCTAssertTrue(CoCFAQ.stickyIndex == 0);
    XCTAssertEqualObjects(CoCFAQ.title, @"Cavern of Cobol FAQ (Read this first)");
    XCTAssertTrue(CoCFAQ.seenPosts == 1);
    XCTAssertEqualObjects(CoCFAQ.author.username, @"Scaevolus");
    XCTAssertTrue(CoCFAQ.totalReplies == 0);
    XCTAssertTrue(CoCFAQ.rating.doubleValue == 0);
    XCTAssertTrue(CoCFAQ.lastPostDate.timeIntervalSince1970 == 1209381240);
    XCTAssertEqualObjects(CoCFAQ.lastPostAuthorName, @"Scaevolus");
    
    AwfulThread *androidAppThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                              matchingPredicateFormat:@"author.username = 'Ferg'"];
    XCTAssertEqual(androidAppThread.starCategory, AwfulStarCategoryRed);
    XCTAssertTrue(androidAppThread.numberOfVotes == 159);
    XCTAssertTrue(androidAppThread.rating.doubleValue == 4.79);
}

- (void)testDebateAndDiscussionThreadList
{
    NSArray *scrapedThreads = [self scrapeFixtureNamed:@"forumdisplay"];
    XCTAssertTrue(scrapedThreads.count == 40);
    NSArray *allThreads = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allThreads.count, scrapedThreads.count);
    NSArray *allCategories = [AwfulCategory fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertTrue(allCategories.count == 1);
    AwfulCategory *discussion = allCategories.firstObject;
    XCTAssertEqualObjects(discussion.name, @"Discussion");
    XCTAssertTrue(discussion.forums.count == 1);
    NSArray *allForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertTrue(allForums.count == 1);
    AwfulForum *debateAndDiscussion = allForums.firstObject;
    XCTAssertEqualObjects(debateAndDiscussion.name, @"Debate & Discussion");
    XCTAssertEqualObjects(debateAndDiscussion.forumID, @"46");
    NSSet *threadForums = [NSSet setWithArray:[allThreads valueForKey:@"forum"]];
    XCTAssertEqualObjects(threadForums, [NSSet setWithObject:debateAndDiscussion]);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    NSArray *allUsernames = [[allUsers valueForKey:@"username"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    XCTAssertEqualObjects(allUsernames, (@[
                                           @"a bad enough dude",
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
                                           @"Zikan",
                                           ]));
    
    AwfulThread *rulesThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                         matchingPredicateFormat:@"title CONTAINS 'Improved Rules'"];
    XCTAssertEqual(rulesThread.starCategory, AwfulStarCategoryNone);
    XCTAssertEqualObjects(rulesThread.threadTagURL.lastPathComponent, @"icon23-banme.gif");
    XCTAssertTrue(rulesThread.sticky);
    XCTAssertFalse(rulesThread.stickyIndex == 0);
    XCTAssertEqualObjects(rulesThread.title, @"The Improved Rules of Debate and Discussion - New Update");
    XCTAssertTrue(rulesThread.seenPosts == 12);
    XCTAssertEqualObjects(rulesThread.author.username, @"tonelok");
    XCTAssertTrue(rulesThread.totalReplies == 11);
    XCTAssertTrue(rulesThread.numberOfVotes == 0);
    XCTAssertTrue(rulesThread.rating.doubleValue == 0);
    XCTAssertTrue(rulesThread.lastPostDate.timeIntervalSince1970 == 1330198920);
    XCTAssertEqualObjects(rulesThread.lastPostAuthorName, @"Xandu");
    
    AwfulThread *venezuelanThread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                              matchingPredicateFormat:@"title BEGINSWITH 'Venezuelan'"];
    XCTAssertEqual(venezuelanThread.starCategory, AwfulStarCategoryNone);
    XCTAssertEqualObjects(venezuelanThread.threadTagURL.lastPathComponent, @"lf-marx.png");
    XCTAssertFalse(venezuelanThread.sticky);
    XCTAssertEqualObjects(venezuelanThread.title, @"Venezuelan elections");
    XCTAssertTrue(venezuelanThread.seenPosts == 0);
    XCTAssertEqualObjects(venezuelanThread.author.username, @"a bad enough dude");
    XCTAssertTrue(venezuelanThread.totalReplies == 410);
    XCTAssertTrue(venezuelanThread.numberOfVotes == 0);
    XCTAssertTrue(venezuelanThread.rating.doubleValue == 0);
    XCTAssertTrue(venezuelanThread.lastPostDate.timeIntervalSince1970 == 1357082460);
    XCTAssertEqualObjects(venezuelanThread.lastPostAuthorName, @"d3c0y2");
}

@end
