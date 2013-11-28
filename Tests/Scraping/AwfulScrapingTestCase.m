//  AwfulScrapingTestCase.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulDataStack.h"
#import "AwfulDocumentScraper.h"

@interface AwfulScrapingTestCase ()

@property (strong, nonatomic) AwfulDataStack *dataStack;

@end

@implementation AwfulScrapingTestCase

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

+ (Class)scraperClass
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)setUp
{
    [super setUp];
    
    // The scraper uses the default time zone. To make the test repeatable, we set a known time zone.
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
}

- (void)tearDown
{
    [self.dataStack deleteStoreAndResetStack];
    [super tearDown];
}

- (id)scrapeFixtureNamed:(NSString *)fixtureName
{
    NSURL *fixtureURL = [[NSBundle bundleForClass:[self class]] URLForResource:fixtureName withExtension:@"html" subdirectory:@"Fixtures"];
    NSError *error;
    NSString *fixtureHTML = [NSString stringWithContentsOfURL:fixtureURL encoding:NSWindowsCP1252StringEncoding error:&error];
    XCTAssertNotNil(fixtureHTML, @"error loading fixture from %@: %@", fixtureURL, error);
    HTMLDocument *document = [HTMLDocument documentWithString:fixtureHTML];
    id <AwfulDocumentScraper> scraper = [[[self class] scraperClass] new];
    NSArray *scrapedThreads = [scraper scrapeDocument:document
                                              fromURL:fixtureURL
                             intoManagedObjectContext:self.managedObjectContext
                                                error:&error];
    XCTAssertNotNil(scrapedThreads, @"error scraping threads: %@", error);
    return scrapedThreads;
}

@end
