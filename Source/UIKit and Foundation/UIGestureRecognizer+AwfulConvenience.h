//  UIGestureRecognizer+AwfulConvenience.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIGestureRecognizer (AwfulConvenience)

/**
 * Stops the gesture recognizer from recognizing, regardless of its current state.
 */
- (void)awful_failImmediately;

@end
