//  UIViewController+AwfulTheme.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulTheme.h"

@interface UIViewController (AwfulTheme)

/**
 * The first non-nil theme in the view controller's hierarchy, starting with itself and continuing through parent and presenting view controllers.
 */
@property (strong, nonatomic) AwfulTheme *theme;

/**
 * Called when the view controller's theme, derived or otherwise, changes. Subclass implementations should reload and/or update any views customized by the theme, and should call the superclass implementation.
 */
- (void)themeDidChange;

@end

/**
 * An AwfulViewController is a thin customization of UIViewController that extends AwfulTheme support.
 *
 * AwfulViewController instances have -themeDidChange called on them after the view loads.
 */
@interface AwfulViewController : UIViewController

@end

/**
 * An AwfulTableViewController is a thin customization of UITableViewController that extends AwfulTheme support.
 */
@interface AwfulTableViewController : UITableViewController

@end

/**
 * An AwfulCollectionViewController is a thin customization of UICollectionViewController that extends AwfulTheme support.
 */
@interface AwfulCollectionViewController : UICollectionViewController

@end

/**
 * Utility function to call -themeDidChange when appropriate on a subtree of a view controller hierarchy.
 *
 * @param viewController The root of the subtree to call -themeDidChange on.
 */
extern void RecursivelyCallThemeDidChangeOn(UIViewController *viewController);
