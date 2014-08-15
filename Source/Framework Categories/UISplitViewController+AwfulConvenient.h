//  UISplitViewController+AwfulConvenient.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UISplitViewController (AwfulConvenient)

/**
 * Animates the primary view controller into view if it is not already visible.
 */
- (void)awful_showPrimaryViewController;

/**
 * Animates the primary view controller out of view if it is currently visible in an overlay.
 */
- (void)awful_hidePrimaryViewController;

@end
