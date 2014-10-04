//  SmiliesTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Smilies;
@import XCTest;

@interface SmiliesTests : XCTestCase

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation SmiliesTests

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSURL *modelURL = [[NSBundle bundleForClass:[Smilie class]] URLForResource:@"Smilies" withExtension:@"momd"];
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        NSError *error;
        if (![storeCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"could not start store coordinator" userInfo:nil];
        }
        _managedObjectContext = [NSManagedObjectContext new];
        _managedObjectContext.persistentStoreCoordinator = storeCoordinator;
    }
    return _managedObjectContext;
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
