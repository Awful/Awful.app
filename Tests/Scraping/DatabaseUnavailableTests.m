//  DatabaseUnavailableTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulForumHierarchyScraper.h"
#import "AwfulPostsPageScraper.h"
#import "AwfulProfileScraper.h"
#import "AwfulThreadListScraper.h"

@interface DatabaseUnavailableTests : AwfulScrapingTestCase

@property (strong, nonatomic) HTMLDocument *fixture;

@end

@implementation DatabaseUnavailableTests

- (void)setUp
{
    [super setUp];
    self.fixture = LoadFixtureNamed(@"database-unavailable");
}

- (void)testForumHierarchy
{
    AwfulForumHierarchyScraper *scraper = [AwfulForumHierarchyScraper scrapeNode:self.fixture intoManagedObjectContext:self.managedObjectContext];
    XCTAssertNotNil(scraper.error);
    XCTAssertTrue([AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext].count == 0);
}

- (void)testPostsPage
{
    AwfulPostsPageScraper *scraper = [AwfulPostsPageScraper scrapeNode:self.fixture intoManagedObjectContext:self.managedObjectContext];
    XCTAssertNotNil(scraper.error);
    XCTAssertTrue([AwfulPost fetchAllInManagedObjectContext:self.managedObjectContext].count == 0);
}

- (void)testProfile
{
    AwfulProfileScraper *scraper = [AwfulProfileScraper scrapeNode:self.fixture intoManagedObjectContext:self.managedObjectContext];
    XCTAssertNotNil(scraper.error);
    XCTAssertTrue([AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext].count == 0);
}

- (void)testThreadList
{
    AwfulThreadListScraper *scraper = [AwfulThreadListScraper scrapeNode:self.fixture intoManagedObjectContext:self.managedObjectContext];
    XCTAssertNotNil(scraper.error);
    XCTAssertTrue([AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext].count == 0);
}

@end
