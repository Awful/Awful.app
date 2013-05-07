//
//  AwfulPopoverController.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-06.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol AwfulPopoverControllerDelegate;

// A loving tribute to UIPopoverController.
//
// AwfulPopoverController has far fewer features compared to UIPopoverController.
@interface AwfulPopoverController : NSObject

// Designated initializer.
- (id)initWithContentViewController:(UIViewController *)contentViewController;

@property (readonly, nonatomic) UIViewController *contentViewController;

@property (weak, nonatomic) id <AwfulPopoverControllerDelegate> delegate;

// Displays the popover, pointing it at the specified location in the view. The arrow always points
// down.
//
// Ensure the popover controller's content view controller has a nonzero value for its
// contentSizeInPopoverView property before presenting the popover.
- (void)presentPopoverFromRect:(CGRect)rect
                        inView:(UIView *)view
                      animated:(BOOL)animated;

// Dismisses the popover.
- (void)dismissPopoverAnimated:(BOOL)animated;

@end


@protocol AwfulPopoverControllerDelegate <NSObject>

- (void)popoverControllerDidDismissPopover:(AwfulPopoverController *)popover;

@end
