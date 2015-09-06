//  SmiliesTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

@interface SmiliesTests : XCTestCase

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation SmiliesTests

- (void)setUp
{
    [super setUp];

    NSManagedObjectModel *model = [SmilieDataStore managedObjectModel];
    NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError *error;
    if (![storeCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"could not start store coordinator" userInfo:nil];
    }
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContext.persistentStoreCoordinator = storeCoordinator;
}

- (void)tearDown
{
    self.managedObjectContext = nil;
    [super tearDown];
}

- (void)testMetadataCreation
{
    Smilie *smilie = [Smilie newInManagedObjectContext:self.managedObjectContext];
    SmilieMetadata *metadata = smilie.metadata;
    XCTAssertNotNil(metadata, @"metadata lazily created by getter");
    XCTAssertEqualObjects(smilie.metadata, metadata, @"metadata created exactly once by getter");
}

- (void)testImageSizeAccessors
{
    {{
        Smilie *smilie = [Smilie newInManagedObjectContext:self.managedObjectContext];
        smilie.text = @":backtowork:";
        smilie.imageSize = CGSizeMake(38, 25);
        NSError *error;
        BOOL ok = [self.managedObjectContext save:&error];
        XCTAssert(ok, @"error saving context: %@", error);
    }}
    
    {{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        NSError *error;
        Smilie *smilie = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error].firstObject;
        XCTAssertNotNil(smilie, @"couldn't find smilie. possible error: %@", error);
        XCTAssert(CGSizeEqualToSize(smilie.imageSize, CGSizeMake(38, 25)));
    }}
}

@end
