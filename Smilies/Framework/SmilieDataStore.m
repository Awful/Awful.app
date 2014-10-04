//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "Smilie.h"

@implementation SmilieDataStore

@synthesize managedObjectContext = _managedObjectContext;

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        NSDictionary *options = @{NSReadOnlyPersistentStoreOption: @YES};
        NSError *error;
        if (![storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"NoMetadata" URL:[[self class] bundledSmilieStoreURL] options:options error:&error]) {
            NSLog(@"%s error adding bundled store: %@", __PRETTY_FUNCTION__, error);
        }
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = storeCoordinator;
    }
    return _managedObjectContext;
}

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[Smilie class]] URLForResource:@"Smilies" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

+ (NSURL *)bundledSmilieStoreURL
{
    return [[NSBundle bundleForClass:[Smilie class]] URLForResource:@"Smilies" withExtension:@"sqlite"];
}

@end
