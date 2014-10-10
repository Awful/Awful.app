//  SmilieMetadata.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Smilies/SmilieManagedObject.h>
@class Smilie;

@interface SmilieMetadata : SmilieManagedObject

@property (readonly, strong, nonatomic) Smilie *smilie;

@property (assign, nonatomic) int16_t favoriteIndex;
@property (assign, nonatomic) BOOL isFavorite;
@property (strong, nonatomic) NSDate *lastUsedDate;
@property (copy, nonatomic) NSString *smilieText;

@end
