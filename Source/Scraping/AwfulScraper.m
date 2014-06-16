//  AwfulScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
#import "AwfulErrorDomain.h"

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
    HTMLElement *body = [self.node firstNodeMatchingSelector:@"body.database_error"];
    if (body) {
        NSString *reason = [[body firstNodeMatchingSelector:@"#msg h1"].textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (reason.length == 0) reason = @"Database unavailable";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.databaseUnavailable userInfo:@{ NSLocalizedDescriptionKey: reason }];
    }
}

@end
