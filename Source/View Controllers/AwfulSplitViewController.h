//  AwfulSplitViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulExpandingSplitViewController.h"

/**
 * An AwfulSplitViewController contains a master view controller and a detail view controller.
 *
 * See AwfulExpandingSplitViewController for an explanation of this odd class hierarchy.
 */
@interface AwfulSplitViewController : AwfulExpandingSplitViewController

/**
 * An array of two view controllers: the master view controller and the detail view controller. Setting is equivalent to calling -setViewControllers:animated: and passing NO for the second parameter.
 *
 * Any UINavigationController in the viewControllers array without a delegate are assigned the split view controller. The split view controller does this in order to hide or show the toolbar as appropriate.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 * If the second parameter is YES, the old detail view controller fades away to reveal the new detail view controller. Master view controller changes are never animated.
 */
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;

/**
 * Convenience for simultaneously setting the second element of the -viewControllers array and hiding the sidebar. If the third parameter is YES, both the change in detail view controller and the hiding of the sidebar are animated as described by -setViewControllers:animated: and -setSidebarHidden:animated:.
 */
- (void)setDetailViewController:(UIViewController *)detailViewController sidebarHidden:(BOOL)sidebarHidden animated:(BOOL)animated;

/**
 * Always show the sidebar in these interface orientations. Setting is equivalent to calling -setStickySidebarInterfaceOrientations:animated: and passing NO for the second parameter.
 */
@property (assign, nonatomic) UIInterfaceOrientationMask stickySidebarInterfaceOrientationMask;

/**
 * If the second parameter is YES, any resizing of the detail view controller's view is animated.
 */
- (void)setStickySidebarInterfaceOrientationMask:(UIInterfaceOrientationMask)stickySidebarInterfaceOrientationMask animated:(BOOL)animated;

/**
 * YES when the sidebar is hidden, or NO when it is visible. Attempts to set to YES when in a sticky sidebar interface orientation will fail silently. Setting is equivalent to calling -setSidebarHidden:animated: and passing NO for the second parameter.
 */
@property (assign, nonatomic) BOOL sidebarHidden;

/**
 * If the second parameter is YES, any movement of the detail view controller's view is animated.
 */
- (void)setSidebarHidden:(BOOL)sidebarHidden animated:(BOOL)animated;

@end

@interface UIViewController (AwfulSplitViewControllerAccess)

/**
 * Returns the nearest split view controller, or nil if the view controller is not contained in a split view controller.
 */
@property (readonly, strong, nonatomic) AwfulSplitViewController *splitViewController;

@end

/**
 * Detail view controllers can conform to this protocol if there is never a reason to show it without the sidebar visible. For example, a placeholder "no selection" view controller has no reason to be solely visible.
 */
@protocol AwfulSplitViewControllerInconsequentialDetail <NSObject>

@end
