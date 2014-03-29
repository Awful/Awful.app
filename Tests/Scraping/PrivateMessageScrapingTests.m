//  PrivateMessageScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulPrivateMessageScraper.h"

@interface PrivateMessageScrapingTests : AwfulScrapingTestCase

@end

@implementation PrivateMessageScrapingTests

+ (Class)scraperClass
{
    return [AwfulPrivateMessageScraper class];
}

- (void)testSingleMessage
{
    AwfulPrivateMessageScraper *scraper = [self scrapeFixtureNamed:@"private-one"];
    AwfulPrivateMessage *message = scraper.privateMessage;
    NSArray *allMessages = [AwfulPrivateMessage fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allMessages.count, (NSUInteger)1);
    NSArray *allUsers = [AwfulPrivateMessage fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allUsers.count, (NSUInteger)1);
    
    XCTAssertEqualObjects(message.messageID, @"4601162");
    XCTAssertEqualObjects(message.subject, @"Awful app");
    XCTAssertTrue(message.seen);
    XCTAssertFalse(message.replied);
    XCTAssertFalse(message.forwarded);
    XCTAssertEqual(message.sentDate.timeIntervalSince1970, 1352408160.);
    XCTAssertNotEqual([message.innerHTML rangeOfString:@"awesome app"].location, (NSUInteger)NSNotFound);
    AwfulUser *from = message.from;
    XCTAssertEqualObjects(from.userID, @"47395");
    XCTAssertEqualObjects(from.username, @"InFlames235");
    XCTAssertEqual(from.regdate.timeIntervalSince1970, 1073952000.);
}

@end
