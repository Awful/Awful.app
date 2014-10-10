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

@end
