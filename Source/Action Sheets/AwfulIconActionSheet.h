//  AwfulIconActionSheet.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulIconActionItem.h"

/**
 * Shows actions in a scrollable grid of icons.
 */
@interface AwfulIconActionSheet : UIView

/**
 * The title of an action sheet is shown atop the grid of icons.
 */
@property (copy, nonatomic) NSString *title;

/**
 * The items already added to an action sheet.
 */
@property (copy, nonatomic) NSArray *items;

/**
 * Adds an item to an action sheet.
 */
- (void)addItem:(AwfulIconActionItem *)item;

/**
 * Displays an action sheet. On iPhone, the sheet is displayed in the middle of an existing view. On iPad, the sheet is shown in a popover.
 *
 * @param rect     On iPhone, ignored. On iPad, the portion of the view that the popover points to.
 * @param view     On iPhone, the view that will host the action sheet. On iPad, the view that the popover points to.
 * @param animated YES if the sheet presentation should be animated, otherwise NO.
 */
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;

/**
 * Displays an action sheet. On iPhone, the sheet is displayed in the middle of the superview of the bar button item's navbar/toolbar. On iPad, the sheet is shown in a popover.
 *
 * @param barButtonItem On iPhone, the item used to locate the view in which to display the sheet. On iPad, the item that the popover points to.
 * @param animated      YES if the sheet presentation should be animated, otherwise NO.
 */
- (void)showFromBarButtonItem:(UIBarButtonItem *)barButtonItem animated:(BOOL)animated;

/**
 * Hides an action sheet.
 *
 * @param animated YES if the sheet dismissal should be animated, otherwise NO.
 */
- (void)dismissAnimated:(BOOL)animated;

@end
