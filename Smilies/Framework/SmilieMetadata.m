//  SmilieMetadata.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieMetadata.h"

@interface SmilieMetadata ()

@property (copy, nonatomic) NSArray *fetchedSmilies;

@end

@implementation SmilieMetadata

@dynamic favoriteIndex;
@dynamic isFavorite;
@dynamic lastUsedDate;
@dynamic smilieText;

@dynamic fetchedSmilies;

- (Smilie *)smilie
{
    return self.fetchedSmilies[0];
}

- (void)addToFavorites
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entity.name];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES"];
    NSError *error;
    NSUInteger favoritesCount = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    NSAssert(favoritesCount != NSNotFound, @"failed to count favorites: %@", error);
    self.favoriteIndex = favoritesCount;
    self.isFavorite = YES;
}

- (void)removeFromFavoritesUpdatingSubsequentIndices
{
    self.isFavorite = NO;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entity.name];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES AND favoriteIndex > %@", @(self.favoriteIndex)];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"favoriteIndex" ascending:YES]];
    NSError *error;
    NSArray *otherFavorites = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    NSAssert(otherFavorites, @"failed to fetch favorites > %@: %@", @(self.favoriteIndex), error);
    for (SmilieMetadata *otherMetadata in otherFavorites) {
        otherMetadata.favoriteIndex--;
    }
}

@end
