//  UIViewController+NavigationEnclosure.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIViewController (NavigationEnclosure)

/**
 * Returns the view controller's navigation controller, lazily creating an AwfulNavigationController if needed. Created navigation controllers adopt the modalPresentationStyle of the view controller.
 */
@property (readonly, nonatomic) UINavigationController *enclosingNavigationController;

@end
