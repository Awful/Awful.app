//  AwfulScraper.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;
@import HTMLReader;

/**
    An AwfulScraper turns HTML into model objects.
 
    AwfulScraper is an abstract class. Subclasses must implement -scrape to do the work, and should expose properties to access the results of scraping.
 */
@interface AwfulScraper : NSObject

/// Convenience method to initialize a scraper and immediately scrape a node.
+ (instancetype)scrapeNode:(HTMLNode *)node intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (instancetype)initWithNode:(HTMLNode *)node managedObjectContext:(NSManagedObjectContext *)managedObjectContext NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly, strong, nonatomic) HTMLNode *node;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (strong, nonatomic) NSError *error;

/// Subclasses must implement. Call super to perform some basic checks for typical site-wide errors (like "database unavailable").
- (void)scrape;

@end
