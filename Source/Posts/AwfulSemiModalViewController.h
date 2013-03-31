//
//  AwfulSemiModalViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulSemiModalViewController : UIViewController

// On iPhone, darkens the viewController's view and slides the semi-modal view up from the bottom.
//
// On iPad, shows the semi-modal view in a popover pointing at the given view. If the interface
// orientation changes, the popover is repositioned to continue pointing at the given view.
- (void)presentFromViewController:(UIViewController *)viewController fromView:(UIView *)view;

// Sent when a user taps outside the semi-modal view. Subclasses should send -dismiss to the semi-
// modal view in response to this message. The only reason not to is if, say, the semi-modal view
// requires user input.
- (void)userDismiss;

// Remove the jump to page controller from the screen. No delegate methods are called as a result.
- (void)dismiss;

// The popover the semi-modal view is currently being shown in.
@property (readonly, nonatomic) UIPopoverController *popover;

// The view covering the background on iPhone; its alpha is animated from 0 to 0.5 as the semi-
// modal view appears. By default its background color is black.
@property (readonly, nonatomic) UIView *coverView;

@end
