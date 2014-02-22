//  UIGestureRecognizer+AwfulConvenience.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIGestureRecognizer+AwfulConvenience.h"

@implementation UIGestureRecognizer (AwfulConvenience)

- (void)awful_failImmediately
{
    // While I don't know why someone would call this on a disabled gesture recognizer, it certainly would be confusing if that resulted in enabling said gesture recognizer.
    if (self.enabled) {
        self.enabled = NO;
        self.enabled = YES;
    }
}

@end
