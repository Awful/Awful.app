//  AwfulScreenCoverView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

// An invisible view that covers the screen, intercepting all touches.
@interface AwfulScreenCoverView : UIView

// Designated initializer.
- (id)initWithWindow:(UIWindow *)window;

// Views that should receive touches.
@property (copy, nonatomic) NSArray *passthroughViews;

// The method will be called on target when the cover view is tapped.
- (void)setTarget:(id)target action:(SEL)action;

@end
