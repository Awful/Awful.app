//
//  IntegrationTest.m
//  Awful
//
//  Created by Nolan Waite on 12-05-08.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>
#import <CoreData/CoreData.h>
#import "AwfulScrapeOperation.h"
#import "AwfulPersistOperation.h"
#import "AwfulForum.h"

@interface IntegrationTest : GHTestCase @end

@implementation IntegrationTest

- (void)testFetchingForums
{
    NSData *data = BundleData(@"gbs.html");
    AwfulForumListScrapeOperation *scrapeOp = [[AwfulForumListScrapeOperation alloc] initWithResponseData:data];
    
    // TODO DRY the shit out of this
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSError *error = nil;
    NSPersistentStoreCoordinator *store = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [store addPersistentStoreWithType:NSInMemoryStoreType
                        configuration:nil
                                  URL:nil
                              options:nil
                                error:&error];
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [context setPersistentStoreCoordinator:store];
    AwfulPersistOperation *persistOp = [[AwfulPersistOperation alloc] initWithManagedObjectContext:context];
    [persistOp addDependency:scrapeOp];
    
    [scrapeOp start];
    
    // This is some bullshit right here. Both operations are not "concurrent" operations (in the
    // NSOperation nomenclature, "concurrent" operations spawn their own threads), so by my reading
    // of the docs (and stepping through the debugger) they should be synchronous operations.
    // Yet without this ridiculous sleep, the persistOp *never starts* because, even though its
    // dependency isFinished, it never isReady.
    //
    // Smells like a race condition somewhere, but I really don't know where.
    usleep(100000);
    
    [persistOp start];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"AwfulForum"];
    NSArray *forums = [context executeFetchRequest:fetchRequest error:NULL];
    GHAssertEquals(forums.count, 76U, nil);
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"forumID == '1'"];
    AwfulForum *gbs = [[context executeFetchRequest:fetchRequest error:NULL] lastObject];
    GHAssertEqualStrings(gbs.name, @"General Bullshit", nil);
}

@end
