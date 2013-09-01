//  AwfulPocketStatusTransformer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
