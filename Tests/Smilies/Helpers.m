//  Helpers.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

SmilieWebArchive * FixtureWebArchive(void)
{
    NSURL *URL = [[NSBundle bundleForClass:[TestDataStore class]] URLForResource:@"showsmilies" withExtension:@"webarchive"];
    return [[SmilieWebArchive alloc] initWithURL:URL];
}

@implementation TestDataStore
{
    NSPersistentStore *_inMemoryStore;
    BOOL _nothingBundled;
}

+ (instancetype)newNothingBundledDataStore
{
    TestDataStore *dataStore = [self new];
    dataStore->_nothingBundled = YES;
    return dataStore;
}

- (NSPersistentStore *)bundledSmilieStore
{
    return _nothingBundled ? nil : super.bundledSmilieStore;
}

- (NSPersistentStore *)appContainerSmilieStore
{
    if (!_inMemoryStore) {
        NSError *error;
        _inMemoryStore = [self.storeCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
        NSAssert(_inMemoryStore, @"error creating in-memory store: %@", error);
    }
    return _inMemoryStore;
}

@end
