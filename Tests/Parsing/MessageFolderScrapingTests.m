//  MessageFolderScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulParsingTestCase.h"
#import "AwfulMessageFolderScraper.h"

@interface MessageFolderScrapingTests : AwfulParsingTestCase

@end

@implementation MessageFolderScrapingTests

+ (Class)scraperClass
{
    return [AwfulMessageFolderScraper class];
}

- (void)testInbox
{
    NSArray *messages = [self scrapeFixtureNamed:@"private-list"];
    XCTAssertEqual(messages.count, (NSUInteger)4);
    NSArray *allMessages = [AwfulPrivateMessage fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(messages.count, allMessages.count);
    NSArray *allUsers = [AwfulUser fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allUsers.count, (NSUInteger)3);
    
    AwfulPrivateMessage *tagged = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                                    matchingPredicateFormat:@"from.username = 'CamH'"];
    XCTAssertEqualObjects(tagged.messageID, @"4549686");
    XCTAssertEqualObjects(tagged.subject, @"Re: Awful app etc.");
    XCTAssertEqual(tagged.sentDate.timeIntervalSince1970, 1348778940.);
    XCTAssertEqualObjects(tagged.threadTag.imageName, @"sex");
    XCTAssertTrue(tagged.replied);
    XCTAssertTrue(tagged.seen);
    XCTAssertFalse(tagged.forwarded);
}

@end
