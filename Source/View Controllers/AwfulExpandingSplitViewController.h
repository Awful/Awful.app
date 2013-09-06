//  AwfulExpandingSplitViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulExpandingSplitViewController is a container view controller with two views, one on the left and one on the right. The right view can optionally encompass the entire view as needed.
 */
@interface AwfulExpandingSplitViewController : UIViewController

/**
 * Returns an initialized AwfulExpandingSplitViewController. This is the designated initializer.
 *
 * @param viewControllers An array of zero, one, or two UIViewController items.
 */
- (id)initWithViewControllers:(NSArray *)viewControllers;

/**
 * The currently (or possibly) visible view controllers.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 * The rightmost view controller. Equivalent to getting or setting the second item of the `viewControllers` array.
 */
@property (strong, nonatomic) UIViewController *detailViewController;

/**
 * YES if the detail (rightmost) view currently encompasses the entire view, or NO if both `viewControllers` are visible. Setting this property is equivalent to calling `-setDetailExpanded:animated:` with `NO` for the `animated` parameter.
 */
@property (assign, nonatomic) BOOL detailExpanded;

/**
 * Expand or collapse the detail view.
 *
 * @param detailExpanded YES if the detail view should encompass the entire view, or NO if both views should be visible.
 * @param animated YES if the expansion or collapse should be animated, or NO if it should take effect immediately.
 */
- (void)setDetailExpanded:(BOOL)detailExpanded animated:(BOOL)animated;

@end

/**
 * A convenience accessor for getting a view controller's expanding split view.
 */
@interface UIViewController (AwfulExpandingSplitViewController)

/**
 * Returns the AwfulExpandingSplitViewController that contains this view controller, or nil if there is none.
 */
@property (readonly, strong, nonatomic) AwfulExpandingSplitViewController *expandingSplitViewController;

@end
