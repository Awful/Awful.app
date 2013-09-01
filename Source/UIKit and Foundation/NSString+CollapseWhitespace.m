//  NSString+CollapseWhitespace.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
