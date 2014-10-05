//  BundledSmiliesTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Smilies;
@import XCTest;

@interface BundledSmiliesTests : XCTestCase

@property (strong, nonatomic) SmilieDataStore *dataStore;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation BundledSmiliesTests

- (SmilieDataStore *)dataStore
{
    if (!_dataStore) {
        _dataStore = [SmilieDataStore new];
    }
    return _dataStore;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return self.dataStore.managedObjectContext;
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
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    XCTAssert(results.count == 1, @"couldn't find :backtowork:, possible error: %@", error);
    
    Smilie *smilie = results[0];
    XCTAssertEqualObjects(smilie.imageURL.lastPathComponent, @"emot-backtowork.gif");
    XCTAssert(CGSizeEqualToSize(smilie.imageSize, CGSizeMake(38, 25)));
}

@end
