//  AwfulCustomBaseURLTransformer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulCustomBaseURLTransformer.h"
#import "AwfulSettings.h"

@implementation AwfulCustomBaseURLTransformer

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
    return settings.customBaseURL ?: @"Default";
}

@end
