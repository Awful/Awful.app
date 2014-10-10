//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "Smilie.h"
#import "SmilieAppContainer.h"

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
        if (![storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[[self class] appContainerSmilieStoreURL] options:nil error:&error]) {
            NSLog(@"%s error adding app container store: %@", __PRETTY_FUNCTION__, error);
        }
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
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

+ (NSURL *)appContainerSmilieStoreURL
{
    NSURL *folder = [SmilieKeyboardSharedContainerURL() URLByAppendingPathComponent:@"Data Store"];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating containing folder: %@", __PRETTY_FUNCTION__, error);
    }
    return [folder URLByAppendingPathComponent:@"Smilies.sqlite"];
}

@end
