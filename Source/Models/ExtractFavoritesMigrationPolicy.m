//  ExtractFavoritesMigrationPolicy.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ExtractFavoritesMigrationPolicy.h"
#import "AwfulSettings.h"

@implementation ExtractFavoritesMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError *__autoreleasing *)error
{
    // The isFavorite attribute is disappearing, so we want to extract the IDs of each favorited
    // forum for later storage in AwfulSettings.
    if ([[sInstance valueForKey:@"isFavorite"] boolValue]) {
        // We'll store the forum IDs in the migration manager's userInfo dictionary.
        if (!manager.userInfo) {
            manager.userInfo = [NSMutableDictionary new];
        }
        NSMutableDictionary *userInfo = (id)manager.userInfo;
        if (!userInfo[@"favorites"]) {
            userInfo[@"favorites"] = [NSMutableArray new];
        }
        NSMutableArray *favorites = userInfo[@"favorites"];
        // We get the AwfulForum instances in an arbitrary order, so fill up the array with dummy
        // values we can remove later.
        NSInteger targetIndex = [[sInstance valueForKey:@"favoriteIndex"] integerValue];
        while ((NSInteger)[favorites count] <= targetIndex) {
            [favorites addObject:@(NSNotFound)];
        }
        // Then replace the dummy value with the actual forum ID.
        [favorites replaceObjectAtIndex:targetIndex
                             withObject:[sInstance valueForKey:@"forumID"]];
    }
    return [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping
                                                      manager:manager error:error];
}

- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager
                   error:(NSError *__autoreleasing *)error
{
    // Now that we're done migrating AwfulForums, we can save our array of forum IDs to
    // AwfulSettings.
    NSMutableArray *favorites = (id)manager.userInfo[@"favorites"];
    [favorites removeObjectIdenticalTo:@(NSNotFound)];
    [AwfulSettings settings].favoriteForums = favorites;
    return [super endEntityMapping:mapping manager:manager error:error];
}

@end
