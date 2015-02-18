//  Helpers.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

SmilieWebArchive * FixtureWebArchive(void)
{
    NSURL *URL = [[NSBundle bundleForClass:[TestDataStore class]] URLForResource:@"showsmilies" withExtension:@"webarchive"];
    return [[SmilieWebArchive alloc] initWithURL:URL];
}

@interface SmilieDataStore ()

- (void)addBundledSmilieStore;

@end

@implementation TestDataStore
{
    NSPersistentStore *_inMemoryStore;
    BOOL _includeBundledDataStore;
}

+ (instancetype)newNothingBundledDataStore
{
    return [[self alloc] initWithBundledDataStore:NO];
}

- (instancetype)initWithBundledDataStore:(BOOL)includeBundledDataStore
{
    _includeBundledDataStore = includeBundledDataStore;
    return [super init];
}

- (instancetype)init
{
    return [self initWithBundledDataStore:YES];
}

- (void)addStores
{
    if (_includeBundledDataStore) {
        [self addBundledSmilieStore];
    }
    
    NSError *error;
    _inMemoryStore = [self.storeCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
    NSAssert(_inMemoryStore, @"error creating in-memory store: %@", error);
}

- (NSPersistentStore *)appContainerSmilieStore
{
    return _inMemoryStore;
}

@end
