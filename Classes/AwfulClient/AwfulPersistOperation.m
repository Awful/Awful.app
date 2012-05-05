//
//  AwfulPersistOperation.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPersistOperation.h"
#import "AwfulScrapeOperation.h"

@interface AwfulPersistOperation ()

@property (strong) NSError *error;

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
@synthesize parentContext = _parentContext;

- (AwfulScrapeOperation *)scrapeOperation
{
    return [self.dependencies objectAtIndex:0];
}

- (void)main
{
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
        // TODO go through scrapeOperation.scrapings and update/insert whatever we find.
        ok = [context save:&error];
    }];
    if (!ok)
        self.error = error;
}

@end
