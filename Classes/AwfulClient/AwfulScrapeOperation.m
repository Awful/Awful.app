//
//  AwfulScrapeOperation.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulScrapeOperation.h"
#import "AwfulHTTPOperation.h"
#import "TFHpple.h"

@interface AwfulScrapeOperation ()

@property (strong) NSError *error;

@property (strong) NSDictionary *scrapings;

@property (strong) NSData *responseData;

@property (readonly, nonatomic) AwfulHTTPOperation *httpOperation;

// Subclasses should override to do their own specific scraping. Return a dictionary of scrapings
// merged with the result of calling to super.
- (NSDictionary *)scrapeData:(NSData *)data;

@end

@implementation AwfulScrapeOperation

- (id)initWithResponseData:(NSData *)data
{
    self = [super init];
    if (self)
    {
        self.responseData = data;
    }
    return self;
}

@synthesize error = _error;
@synthesize scrapings = _scrapings;
@synthesize responseData = _responseData;

- (AwfulHTTPOperation *)httpOperation
{
    return self.dependencies.count > 0 ? [self.dependencies objectAtIndex:0] : nil;
}

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled])
            return;
        if ([self.httpOperation isCancelled])
        {
            [self cancel];
            return;
        }
        if (self.httpOperation.error)
        {
            self.error = self.httpOperation.error;
            return;
        }
        NSData *data = self.responseData;
        if (!data)
            data = self.httpOperation.responseData;
        self.scrapings = [self scrapeData:data];
    }
}

- (NSDictionary *)scrapeData:(NSData *)data
{
    return [NSDictionary new];
}

@end

@interface NSDictionary (Awful)

- (NSDictionary *)awful_dictionaryMergedWithDictionary:(NSDictionary *)other;

@end

const struct AwfulScrapingsKeys AwfulScrapingsKeys =
{
    .Forums = @"forums",
};

@implementation AwfulForumListScrapeOperation

- (NSDictionary *)scrapeData:(NSData *)data
{
    TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:data];
    NSArray *listOfForumElements = [pageData search:@"//select[@name='forumid']/option"];
    
    NSMutableArray *forums = [NSMutableArray array];
    NSMutableArray *parents = [NSMutableArray array];
    
    int lastDashesCount = 0;
    int index = 0;
    
    for (TFHppleElement *forumElement in listOfForumElements)
    {
        NSString *forumID = [forumElement objectForKey:@"value"];
        if ([forumID intValue] <= 0)
            continue;
        NSString *forumName = [forumElement content];
        
        int numDashes = 0;
        for (NSUInteger i = 0; i < forumName.length; i++)
        {
            unichar c = [forumName characterAtIndex:i];
            if (c == '-')
                numDashes++;
            else if (c == ' ')
                break;
        }
        
        int substringIndex = numDashes;
        if (numDashes > 0)
            substringIndex += 1; // space after last '-'
        NSString *actualForumName = [forumName substringFromIndex:substringIndex];
        
        NSMutableDictionary *forum = [NSMutableDictionary new];
        [forum setObject:forumID forKey:@"forumID"];
        [forum setObject:actualForumName forKey:@"name"];
        [forum setObject:[NSNumber numberWithInt:index] forKey:@"index"];
        
        if (numDashes > lastDashesCount && forums.count > 0)
        {
            [parents addObject:[forums lastObject]];
        }
        else if (numDashes < lastDashesCount)
        {
            int diff = lastDashesCount - numDashes;
            for (int killer = 0; killer < diff / 2; killer++)
                [parents removeLastObject];
        }
        
        if (parents.count > 0)
            [forum setObject:[parents lastObject] forKey:@"parent"];
        
        lastDashesCount = numDashes;
        [forums addObject:forum];
        index++;
    }
    return [[NSDictionary dictionaryWithObject:forums
                                        forKey:AwfulScrapingsKeys.Forums]
            awful_dictionaryMergedWithDictionary:[super scrapeData:data]];
}

@end

@implementation NSDictionary (Awful)

- (NSDictionary *)awful_dictionaryMergedWithDictionary:(NSDictionary *)other
{
    NSMutableDictionary *merged = [self mutableCopy];
    [merged addEntriesFromDictionary:other];
    return merged;
}

@end
