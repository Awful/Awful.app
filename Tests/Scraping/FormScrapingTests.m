//  FormScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulForm.h"

@interface FormScrapingTests : AwfulScrapingTestCase

@end

@implementation FormScrapingTests

- (AwfulForm *)scrapeFormFromFixtureNamed:(NSString *)fixtureName
{
    HTMLDocument *document = LoadFixtureNamed(fixtureName);
    HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
    AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
    [form scrapeThreadTagsIntoManagedObjectContext:self.managedObjectContext];
    NSError *error;
    BOOL ok = [self.managedObjectContext save:&error];
    NSAssert(ok, @"error saving context after scraping thread tags: %@", error);
    return form;
}

- (void)testReply
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"newreply"];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)0);
    NSMutableDictionary *parameters = [form recommendedParameters];
    XCTAssertEqualObjects(parameters[@"action"], @"postreply");
    XCTAssertEqualObjects(parameters[@"threadid"], @"3507451");
    XCTAssertEqualObjects(parameters[@"formkey"], @"0253d85a945b60daa0165f718df82b8a");
    XCTAssertEqualObjects(parameters[@"form_cookie"], @"80c74b48f557");
    XCTAssertNotNil(parameters[@"message"]);
    XCTAssertNotEqual([parameters[@"message"] rangeOfString:@"terrible"].location, (NSUInteger)NSNotFound);
    XCTAssertNotNil(parameters[@"parseurl"]);
    XCTAssertNotNil(parameters[@"bookmark"]);
    XCTAssertNil(parameters[@"disablesmilies"]);
    XCTAssertNil(parameters[@"signature"]);
}

- (void)testReplyWithAmazonSearch
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"newreply-amazon-form"];
    XCTAssertNotNil([form recommendedParameters][@"threadid"]);
}

- (void)testThread
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"newthread"];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)51);
    NSArray *allThreadTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allThreadTags.count, form.threadTags.count);
    XCTAssertTrue(form.secondaryThreadTags.count == 0);
    NSDictionary *parameters = form.allParameters;
    XCTAssertNotNil(parameters[@"subject"]);
    XCTAssertNotNil(parameters[@"message"]);
    XCTAssertEqualObjects(parameters[@"forumid"], @"1");
    XCTAssertEqualObjects(parameters[@"action"], @"postthread");
    XCTAssertEqualObjects(parameters[@"formkey"], @"0253d85a945b60daa0165f718df82b8a");
    XCTAssertEqualObjects(parameters[@"form_cookie"], @"e29a15add831");
    XCTAssertEqualObjects(parameters[@"parseurl"], @"yes");
    XCTAssertEqualObjects(parameters[@"bookmark"], @"yes");
}

- (void)testAskTellThread
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"newthread-at"];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)55);
    XCTAssertEqual(form.secondaryThreadTags.count, (NSUInteger)2);
    NSArray *secondaryTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"imageName IN { 'ama', 'tma' }"];
    XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count);
}

- (void)testSAMartThread
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"newthread-samart"];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)69);
    XCTAssertEqual(form.secondaryThreadTags.count, (NSUInteger)4);
    NSArray *secondaryTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"imageName LIKE 'icon*ing'"];
    NSIndexSet *secondaryIndexes = [secondaryTags indexesOfObjectsPassingTest:^BOOL(AwfulThreadTag *threadTag, NSUInteger i, BOOL *stop) {
        return threadTag.threadTagID.integerValue < 5;
    }];
    XCTAssertEqual(secondaryIndexes.count, form.secondaryThreadTags.count);
}

- (void)testMessage
{
    AwfulForm *form = [self scrapeFormFromFixtureNamed:@"private-reply"];
    NSDictionary *parameters = form.allParameters;
    XCTAssertNotNil(parameters[@"message"]);
    XCTAssertNotEqual([parameters[@"message"] rangeOfString:@"InFlames235 wrote"].location, (NSUInteger)NSNotFound);
}

@end
