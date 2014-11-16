//  AwfulLoadingView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulTheme.h"

/**
 * A view that covers its superview with an indeterminate progress indicator.
 */
@interface AwfulLoadingView : UIView

/**
 * Conveniently create a loading view configured for a particular theme.
 */
+ (instancetype)loadingViewForTheme:(AwfulTheme *)theme;

@end
