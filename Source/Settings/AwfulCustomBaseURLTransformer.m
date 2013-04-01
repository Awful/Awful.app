//
//  AwfulCustomBaseURLTransformer.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-01.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
    if (settings.customBaseURL) {
        return settings.customBaseURL;
    } else if (settings.useDevDotForums) {
        return @"dev.forums";
    } else {
        return @"Default";
    }
}

@end
