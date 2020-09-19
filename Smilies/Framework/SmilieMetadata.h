//  SmilieMetadata.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Smilies/SmilieManagedObject.h>
@class Smilie;

@interface SmilieMetadata : SmilieManagedObject

@property (readonly, strong, nonatomic) Smilie *smilie;

/**
 Starts at 0. Ignored if `isFavorite` is `NO`.
 */
@property (assign, nonatomic) int16_t favoriteIndex;

@property (assign, nonatomic) BOOL isFavorite;
@property (strong, nonatomic) NSDate *lastUsedDate;
@property (copy, nonatomic) NSString *smilieText;

/**
 Marks the smilie as a favorite and adds it to the end of the favorites list. The `managedObjectContext` is not saved.
 */
- (void)addToFavorites;

/**
 Removes the smilie from the favorites list. All favorites after it are renumbered. The ``managedObjectContext` is not saved.
 */
- (void)removeFromFavoritesUpdatingSubsequentIndices;

@end
