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

@end
