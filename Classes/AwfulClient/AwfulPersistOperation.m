//
//  AwfulPersistOperation.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPersistOperation.h"
#import "AwfulScrapeOperation.h"
#import "AwfulForum.h"

@interface AwfulPersistOperation ()

@property (strong) NSError *error;

@property (strong) NSArray *forumObjectIDs;

@property (strong) NSManagedObjectContext *parentContext;

@property (readonly, nonatomic) AwfulScrapeOperation *scrapeOperation;

@end

@implementation AwfulPersistOperation

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super init];
    if (self)
    {
        self.parentContext = managedObjectContext;
    }
    return self;
}

@synthesize error = _error;
@synthesize forumObjectIDs = _forumObjectIDs;
@synthesize parentContext = _parentContext;

- (AwfulScrapeOperation *)scrapeOperation
{
    if (self.dependencies.count == 0)
        return nil;
    return [self.dependencies objectAtIndex:0];
}

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled])
            return;
        if ([self.scrapeOperation isCancelled])
        {
            [self cancel];
            return;
        }
        if (self.scrapeOperation.error)
        {
            self.error = self.scrapeOperation.error;
            return;
        }
        
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.parentContext = self.parentContext;
        
        __block BOOL ok;
        __block NSError *error;
        [context performBlockAndWait:^{
            NSArray *forums = UpdateAndInsertForums(context, self.scrapeOperation.scrapings);
            ok = [context save:&error];
            self.forumObjectIDs = [forums valueForKey:@"objectID"];
        }];
        if (!ok)
            self.error = error;
    }
}

// This assumes that parent forums appear before their children in scrapings.
static NSArray *UpdateAndInsertForums(NSManagedObjectContext *context, NSDictionary *scrapings)
{
    // We'll look everything up by ID, so prepare a couple of dictionaries.
    NSArray *forumScrapings = [scrapings objectForKey:AwfulScrapingsKeys.Forums];
    if (!forumScrapings)
        return nil;
    NSMutableDictionary *scrapingsByID = [NSMutableDictionary new];
    for (NSDictionary *forum in forumScrapings)
        [scrapingsByID setObject:forum forKey:[forum objectForKey:@"forumID"]];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"AwfulForum"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"forumID IN %@",
                              [scrapingsByID allKeys]];
    NSError *error;
    NSArray *existingForums = [context executeFetchRequest:fetchRequest error:&error];
    if (!existingForums)
    {
        NSLog(@"error fetching existing forums: %@", error);
        return nil;
    }
    NSMutableDictionary *existingByID = [NSMutableDictionary new];
    for (AwfulForum *forum in existingForums)
        [existingByID setObject:forum forKey:[forum valueForKey:@"forumID"]];
    
    // Update what we already have, insert whatever we don't.
    for (NSString *forumID in [forumScrapings valueForKey:@"forumID"])
    {
        AwfulForum *existing = [existingByID objectForKey:forumID];
        if (!existing)
        {
            existing = [NSEntityDescription insertNewObjectForEntityForName:@"AwfulForum"
                                                     inManagedObjectContext:context];
            existing.forumID = forumID;
            // If a parent is new, its children need to find it, so insert it into our lookup.
            [existingByID setObject:existing forKey:forumID];
        }
        NSDictionary *scraped = [scrapingsByID objectForKey:forumID];
        NSString *name = [scraped objectForKey:@"name"];
        if (name)
            existing.name = name;
        NSNumber *index = [scraped objectForKey:@"index"];
        if (index)
            existing.index = index;
        NSDictionary *parent = [scraped objectForKey:@"parent"];
        if (parent)
            existing.parentForum = [existingByID objectForKey:[parent objectForKey:@"forumID"]];
    }
    return [existingByID allValues];
}

@end
