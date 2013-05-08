//
//  AwfulScreenCoverView.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-07.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
