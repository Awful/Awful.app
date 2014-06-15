//  UIView+AwfulConvenient.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIView (AwfulConvenient)

/**
 * Returns the view controller nearest to the view, or nil if a view controller cannot be found.
 */
@property (readonly, strong, nonatomic) UIViewController *awful_viewController;

@end
