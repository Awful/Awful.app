//  AwfulSemiModalViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * An AwfulSemiModalViewController has custom modal presentation behavior intended to provide context by appearing next to, or pointing at, relevant content in the presenting view controller.
 */
@interface AwfulSemiModalViewController : AwfulViewController

typedef CGRect (^AwfulSemiModalRectInViewBlock)(UIView *view);

/**
 * Presents the semi-modal view controller from the view's view controller, dimming the contents surrounding the context.
 *
 * @param regionBlock A block called to determine which region of the view provides context. The block is called once immediately and may be called whenever the interface orientation changes. The block is released once the semi-modal view controller is dismissed. If nil, the view's bounds is used as the context region.
 */
- (void)presentFromView:(UIView *)view highlightingRegionReturnedByBlock:(AwfulSemiModalRectInViewBlock)regionBlock;

/**
 * Presents the semi-modal view controller in a popover that points at a bar button item.
 */
- (void)presentInPopoverFromBarButtonItem:(UIBarButtonItem *)barButtonItem;

/**
 * Presents the semi-modal view controller in a popover that points at part of a view, adjusting that region after orientation changes.
 *
 * @param regionBlock A block called to determine which region of the view provides context. The block is called once immediately and may be called whenever the interface orientation changes. The block is released once the semi-modal view controller is dismissed. If nil, the view's bounds is used as the region.
 */
- (void)presentInPopoverFromView:(UIView *)view pointingToRegionReturnedByBlock:(AwfulSemiModalRectInViewBlock)regionBlock;

/**
 * Dismisses the semi-modal view controller, regardless of how it was presented.
 *
 * @param completionBlock A block to call after dismissing the semi-modal view controller.
 */
- (void)dismissCompletion:(void (^)(void))completionBlock;

/**
 * Subclasses must override to return a size that considers the view's current size a maximum in both dimensions. If it is impossible to fulfill those constraints, try not to stray too far.
 */
- (CGSize)preferredContentSize;

/**
 * Handy reminder to call super.
 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration __attribute__((objc_requires_super));

@end
