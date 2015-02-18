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

@end
