//  BundledSmiliesTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

@interface BundledSmiliesTests : XCTestCase

@property (strong, nonatomic) TestDataStore *dataStore;

@end

@implementation BundledSmiliesTests

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

- (void)testBacktowork
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text = %@", @":backtowork:"];
    NSError *error;
    NSArray *results = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    XCTAssert(results.count == 1, @"couldn't find :backtowork:, possible error: %@", error);
    
    Smilie *smilie = results[0];
    XCTAssertEqualObjects(smilie.imageURL.lastPathComponent, @"emot-backtowork.gif");
    XCTAssert(CGSizeEqualToSize(smilie.imageSize, CGSizeMake(38, 25)));
}

- (void)testDeletion
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text = %@", @":backtowork:"];
    // Honestly not sure what deletion means for a read-only persistent store, but as long as it doesn't crash I'm ok with it.
    fetchRequest.affectedStores = @[self.dataStore.bundledSmilieStore];
    NSError *error;
    NSArray *results = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(results.count, 1U);

    Smilie *smilie = results[0];
    NSManagedObjectContext *context = smilie.managedObjectContext;
    [context deleteObject:smilie];
    [context save:&error];

    NSArray *newResults = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(newResults.count, 0U);
}

@end
