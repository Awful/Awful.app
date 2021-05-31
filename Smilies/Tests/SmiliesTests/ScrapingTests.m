//  ScrapingTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"
@import HTMLReader;

@interface ScrapingTests : XCTestCase

@property (strong, nonatomic) SmilieWebArchive *webArchive;
@property (assign, nonatomic) NSUInteger bundledSmilieCount;

@end

@implementation ScrapingTests

- (SmilieWebArchive *)webArchive
{
    if (!_webArchive) {
        _webArchive = FixtureWebArchive();
    }
    return _webArchive;
}

- (NSUInteger)bundledSmilieCount
{
    if (_bundledSmilieCount == 0) {
        SmilieDataStore *bundledStore = [TestDataStore new];
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.affectedStores = @[bundledStore.bundledSmilieStore];
        NSError *error;
        _bundledSmilieCount = [bundledStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
        NSAssert(_bundledSmilieCount != NSNotFound, @"error fetching: %@", error);
    }
    return _bundledSmilieCount;
}

- (void)testScrapeWithoutBundledSmilies
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    NSError *error;
    
    SmilieDataStore *dataStore = [TestDataStore newNothingBundledDataStore];
    NSUInteger precount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(precount, 0U, @"possible error: %@", error);
    
    SmilieScrapeAndInsertNewSmiliesOperation *operation = [[SmilieScrapeAndInsertNewSmiliesOperation alloc] initWithDataStore:dataStore smilieListHTML:self.webArchive.mainFrameHTML];
    [operation start];
    
    NSUInteger actual = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(actual, self.bundledSmilieCount, @"possible error: %@", error);
}

- (void)testScrapeWithBundledSmilies
{
    SmilieDataStore *dataStore = [TestDataStore new];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    NSError *error;
    NSUInteger precount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    NSAssert(precount != NSNotFound, @"error fetching: %@", error);

    SmilieScrapeAndInsertNewSmiliesOperation *operation = [[SmilieScrapeAndInsertNewSmiliesOperation alloc] initWithDataStore:dataStore smilieListHTML:self.webArchive.mainFrameHTML];
    [operation start];
    
    NSUInteger postcount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(precount, postcount);
}

- (void)testNewFirstMiddleLastSmilieScrape
{
    SmilieDataStore *dataStore = [TestDataStore newNothingBundledDataStore];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    NSError *error;
    NSUInteger precount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssert(precount == 0, @"possible error: %@", error);
    
    HTMLDocument *holeyDocument = [HTMLDocument documentWithString:self.webArchive.mainFrameHTML];
    HTMLElement *first = [holeyDocument firstNodeMatchingSelector:@"img[title=frown]"];
    HTMLElement *middle = [holeyDocument firstNodeMatchingSelector:@"img[title='Responsibility Scallop']"];
    HTMLElement *end = [holeyDocument firstNodeMatchingSelector:@"img[title='Oh you lustful devil you']"];
    for (HTMLElement *img in @[first, middle, end]) {
        HTMLElement *li = img.parentElement;
        [li.parentNode.mutableChildren removeObject:li];
    }
    NSString *holeyHTML = [holeyDocument innerHTML];
    
    SmilieScrapeAndInsertNewSmiliesOperation *operation = [[SmilieScrapeAndInsertNewSmiliesOperation alloc] initWithDataStore:dataStore smilieListHTML:holeyHTML];
    [operation start];
    
    NSUInteger midcount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(midcount, self.bundledSmilieCount - 3, @"possible error: %@", error);
    
    operation = [[SmilieScrapeAndInsertNewSmiliesOperation alloc] initWithDataStore:dataStore smilieListHTML:self.webArchive.mainFrameHTML];
    [operation start];
    
    NSUInteger endcount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(endcount, self.bundledSmilieCount, @"possible error: %@", error);
}

@end
