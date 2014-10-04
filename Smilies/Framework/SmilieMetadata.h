//  SmilieMetadata.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieManagedObject.h"

@interface SmilieMetadata : SmilieManagedObject

@property (copy, nonatomic) NSString *smilieText;
@property (assign, nonatomic) int16_t favoriteIndex;
@property (assign, nonatomic) BOOL isFavorite;
@property (strong, nonatomic) NSDate *lastUsedDate;

@end
