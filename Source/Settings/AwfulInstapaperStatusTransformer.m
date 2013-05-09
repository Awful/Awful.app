//
//  AwfulInstapaperStatusTransformer.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-09.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulInstapaperStatusTransformer.h"
#import "AwfulSettings.h"

@implementation AwfulInstapaperStatusTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(AwfulSettings *)settings
{
    if (settings.instapaperUsername) {
        return @"Log Out of Instapaper";
    } else {
        return @"Log In to Instapaper";
    }
}

@end
