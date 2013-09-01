//  AwfulInstapaperStatusTransformer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
