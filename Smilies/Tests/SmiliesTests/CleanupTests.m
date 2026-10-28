//  CleanupTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

@interface CleanupTests : XCTestCase

@property (strong, nonatomic) TestDataStore *dataStore;

@end

@implementation CleanupTests

- (void)setUp
{
    [super setUp];
    self.dataStore = [TestDataStore new];
}

- (void)tearDown
{
    self.dataStore = nil;
    [super tearDown];
}

- (void)testCleanupRequired
{
    Smilie *backtowork = [Smilie newInManagedObjectContext:self.dataStore.managedObjectContext];
    backtowork.text = @":backtowork:";
    NSError *error;
    if (![backtowork.managedObjectContext save:&error]) {
        NSAssert(NO, @"error saving: %@", error);
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text = %@", backtowork.text];
    NSUInteger precount = [self.dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(precount, 2U, @"possible error: %@", error);
    
    SmilieCleanUpDuplicateDataOperation *operation = [[SmilieCleanUpDuplicateDataOperation alloc] initWithDataStore:self.dataStore];
    [operation start];
    
    NSUInteger postcount = [self.dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(postcount, 1U, @"possible error: %@", error);
}

- (void)testCleanupOnBackgroundQueue
{
    // The keyboard runs cleanup on its own operation queue, not the main thread.
    Smilie *backtowork = [Smilie newInManagedObjectContext:self.dataStore.managedObjectContext];
    backtowork.text = @":backtowork:";
    NSError *error;
    if (![backtowork.managedObjectContext save:&error]) {
        NSAssert(NO, @"error saving: %@", error);
    }

    SmilieCleanUpDuplicateDataOperation *operation = [[SmilieCleanUpDuplicateDataOperation alloc] initWithDataStore:self.dataStore];
    XCTestExpectation *finished = [self expectationWithDescription:@"cleanup finished"];
    operation.completionBlock = ^{
        [finished fulfill];
    };
    NSOperationQueue *queue = [NSOperationQueue new];
    [queue addOperation:operation];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text = %@", @":backtowork:"];
    NSUInteger postcount = [self.dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(postcount, 1U, @"possible error: %@", error);

    NSDictionary *bundledMetadata = [self.dataStore.storeCoordinator metadataForPersistentStore:self.dataStore.bundledSmilieStore];
    NSDictionary *appContainerMetadata = [self.dataStore.storeCoordinator metadataForPersistentStore:self.dataStore.appContainerSmilieStore];
    XCTAssertEqualObjects(appContainerMetadata[SmilieMetadataVersionKey], bundledMetadata[SmilieMetadataVersionKey] ?: @0);
}

@end
