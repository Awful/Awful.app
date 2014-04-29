//  PostScrapingTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrapingTestCase.h"
#import "AwfulPostScraper.h"

@interface PostScrapingTests : AwfulScrapingTestCase

@end

@implementation PostScrapingTests

+ (Class)scraperClass
{
    return [AwfulPostScraper class];
}

- (void)testIgnoredPost
{
    AwfulPostScraper *scraper = [self scrapeFixtureNamed:@"showpost"];
    AwfulPost *post = scraper.post;
    XCTAssertTrue([post.innerHTML rangeOfString:@"Which command?"].location != NSNotFound);
    AwfulUser *author = post.author;
    XCTAssertEqualObjects(author.username, @"The Dave");
    
}

@end
