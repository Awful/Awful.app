//  FormScrapingTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulForm.h"
#import "AwfulFormScraper.h"

@interface FormScrapingTests : AwfulScrapingTestCase

@end

@implementation FormScrapingTests

+ (Class)scraperClass
{
    return [AwfulFormScraper class];
}

- (void)testReply
{
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"newreply"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)1);
    AwfulForm *form = forms[0];
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
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"newreply-amazon-form"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)2);
    AwfulForm *replyForm = forms[1];
    XCTAssertNotNil([replyForm recommendedParameters][@"threadid"]);
}

- (void)testThread
{
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"newthread"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)1);
    AwfulForm *form = forms[0];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)51);
    NSArray *allThreadTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext];
    XCTAssertEqual(allThreadTags.count, form.threadTags.count);
    XCTAssertNil(form.secondaryThreadTags);
    NSArray *textNames = [form.texts valueForKey:@"name"];
    XCTAssertTrue([textNames containsObject:@"subject"]);
    XCTAssertTrue([textNames containsObject:@"message"]);
    NSMutableDictionary *parameters = [form recommendedParameters];
    XCTAssertEqualObjects(parameters[@"forumid"], @"1");
    XCTAssertEqualObjects(parameters[@"action"], @"postthread");
    XCTAssertEqualObjects(parameters[@"formkey"], @"0253d85a945b60daa0165f718df82b8a");
    XCTAssertEqualObjects(parameters[@"form_cookie"], @"e29a15add831");
    XCTAssertEqualObjects(parameters[@"parseurl"], @"yes");
    XCTAssertEqualObjects(parameters[@"bookmark"], @"yes");
}

- (void)testAskTellThread
{
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"newthread-at"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)1);
    AwfulForm *form = forms[0];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)55);
    XCTAssertEqual(form.secondaryThreadTags.count, (NSUInteger)2);
    NSArray *secondaryTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"imageName IN { 'ama', 'tma' }"];
    XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count);
}

- (void)testSAMartThread
{
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"newthread-samart"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)1);
    AwfulForm *form = forms[0];
    XCTAssertEqual(form.threadTags.count, (NSUInteger)69);
    XCTAssertEqual(form.secondaryThreadTags.count, (NSUInteger)4);
    NSArray *secondaryTags = [AwfulThreadTag fetchAllInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"imageName LIKE 'icon*ing'"];
    XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count);
}

- (void)testMessage
{
    AwfulFormScraper *scraper = [self scrapeFixtureNamed:@"private-reply"];
    NSArray *forms = scraper.forms;
    XCTAssertEqual(forms.count, (NSUInteger)1);
    AwfulForm *form = forms[0];
    AwfulFormItem *messageItem;
    for (AwfulFormItem *text in form.texts) {
        if ([text.name isEqualToString:@"message"]) {
            messageItem = text;
            break;
        }
    }
    XCTAssertNotNil(messageItem);
    XCTAssertNotEqual([messageItem.value rangeOfString:@"InFlames235 wrote"].location, (NSUInteger)NSNotFound);
}

@end
