//  AwfulScrapingTestCase.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <XCTest/XCTest.h>
#import "AwfulScraper.h"

@interface AwfulScrapingTestCase : XCTestCase

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

+ (Class)scraperClass;

- (id)scrapeFixtureNamed:(NSString *)fixtureName;

@end

extern HTMLDocument * LoadFixtureNamed(NSString *basename);
