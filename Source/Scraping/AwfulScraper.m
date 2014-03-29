//  AwfulScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

@implementation AwfulScraper

+ (instancetype)scrapeNode:(HTMLNode *)node intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulScraper *scraper = [[self alloc] initWithNode:node managedObjectContext:managedObjectContext];
    [scraper scrape];
    return scraper;
}

- (id)initWithNode:(HTMLNode *)node managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super init];
    if (!self) return nil;
    
    _node = node;
    _managedObjectContext = managedObjectContext;
    
    return self;
}

- (void)scrape
{
    [self doesNotRecognizeSelector:_cmd];
}

@end
