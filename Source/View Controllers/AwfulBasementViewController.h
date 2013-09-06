//  AwfulBasementViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulBasementViewController is a container view controller that keeps a sidebar underneath its main view.
 */
@interface AwfulBasementViewController : UIViewController

/**
 * Returns an initialized AwfulBasementViewController. This is the designated initializer.
 *
 * @param viewControllers An array of UIViewController objects.
 */
- (id)initWithViewControllers:(NSArray *)viewControllers;

/**
 * An array of UIViewController objects shown in the sidebar. Each UIViewController's `tabBarItem` is used in the sidebar.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 * The currently-visible view controller. Must be an item in the `viewControllers` array.
 */
@property (strong, nonatomic) UIViewController *selectedViewController;

/**
 * The index of the selectedViewController within the `viewControllers` array.
 */
@property (assign, nonatomic) NSUInteger selectedIndex;

/**
 * YES if the sidebar is visible, or NO otherwise. Defaults to NO.
 *
 * Assigning a value is equivalent to sending `-setSidebarVisible:animated:` with NO for the `animated` parameter.
 */
@property (assign, nonatomic) BOOL sidebarVisible;

/**
 * Show or hide the sidebar.
 *
 * @param sidebarVisible YES if the sidebar should be shown, or NO if it should be hidden.
 * @param animated YES if the transition should be animated, or NO if the transition should be immediate.
 */
- (void)setSidebarVisible:(BOOL)sidebarVisible animated:(BOOL)animated;

@end
