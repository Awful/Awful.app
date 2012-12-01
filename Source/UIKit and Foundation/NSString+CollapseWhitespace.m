//
//  NSString+CollapseWhitespace.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSString+CollapseWhitespace.h"

@implementation NSString (CollapseWhitespace)

- (NSString *)stringByCollapsingWhitespace
{
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s+"
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error creating whitespace-collapsing regex: %@", error);
    }
    return [regex stringByReplacingMatchesInString:self
                                           options:0
                                             range:NSMakeRange(0, [self length])
                                      withTemplate:@" "];
}

@end
