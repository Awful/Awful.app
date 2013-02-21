//
//  ExtractFavoritesMigrationPolicy.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-14.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "ExtractFavoritesMigrationPolicy.h"
#import "AwfulSettings.h"

@implementation ExtractFavoritesMigrationPolicy

- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager
                     error:(NSError *__autoreleasing *)error
{
    [AwfulSettings settings].favoriteForums = nil;
    return [super beginEntityMapping:mapping manager:manager error:error];
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError *__autoreleasing *)error
{
    if ([[sInstance valueForKey:@"isFavorite"] boolValue]) {
        NSMutableArray *favorites = [[AwfulSettings settings].favoriteForums mutableCopy];
        if (!favorites) favorites = [NSMutableArray new];
        NSInteger targetIndex = [[sInstance valueForKey:@"favoriteIndex"] integerValue];
        while ((NSInteger)[favorites count] <= targetIndex) {
            [favorites addObject:@(NSNotFound)];
        }
        [favorites replaceObjectAtIndex:targetIndex
                             withObject:[sInstance valueForKey:@"forumID"]];
        [AwfulSettings settings].favoriteForums = favorites;
    }
    return [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping
                                                      manager:manager error:error];
}

- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager
                   error:(NSError *__autoreleasing *)error
{
    NSMutableArray *favorites = [[AwfulSettings settings].favoriteForums mutableCopy];
    [favorites removeObjectIdenticalTo:@(NSNotFound)];
    [AwfulSettings settings].favoriteForums = favorites;
    return [super endEntityMapping:mapping manager:manager error:error];
}

@end
