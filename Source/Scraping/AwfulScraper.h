//  AwfulScraper.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"
#import <HTMLReader/HTMLReader.h>

/**
 * An AwfulScraper turns HTML into model objects.
 *
 * AwfulScraper is an abstract class. Subclasses must implement -scrape to do the work, and should expose properties to access the results of scraping.
 */
@interface AwfulScraper : NSObject

/**
 * Convenience method to initialize a scraper and immediately scrape a node.
 */
+ (instancetype)scrapeNode:(HTMLNode *)node intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Designated initializer.
 */
- (id)initWithNode:(HTMLNode *)node managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong, nonatomic) HTMLNode *node;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (strong, nonatomic) NSError *error;

/**
 * Subclasses must implement. Do not call the superclass implementation.
 */
- (void)scrape;

@end
