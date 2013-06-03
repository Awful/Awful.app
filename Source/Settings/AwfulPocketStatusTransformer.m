//
//  AwfulPocketStatusTransformer.m
//  Awful
//
//  Created by Simon Frost on 03/05/2013.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPocketStatusTransformer.h"
#import "AwfulSettings.h"
#import <PocketAPI/PocketAPI.h>

@implementation AwfulPocketStatusTransformer

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
    if ([[PocketAPI sharedAPI] isLoggedIn]) {
        return @"Log Out of Pocket";
    } else {
        return @"Log In to Pocket";
    }
}

@end
