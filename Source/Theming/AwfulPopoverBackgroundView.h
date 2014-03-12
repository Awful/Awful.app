//  AwfulPopoverBackgroundView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulTheme.h"

/**
 * An AwfulPopoverBackgroundView doesn't stupidly animate its background color, and using it prevents stupid dimming when using UIPopoverController.
 */
@interface AwfulPopoverBackgroundView : UIPopoverBackgroundView

@property (strong, nonatomic) AwfulTheme *theme;

@end
