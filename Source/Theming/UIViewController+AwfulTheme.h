//  UIViewController+AwfulTheme.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulTheme.h"

@interface UIViewController (AwfulTheme) 

/**
 * Called when the view controller's theme, derived or otherwise, changes. Subclass implementations should reload and/or update any views customized by the theme, and should call the superclass implementation.
 */
- (void)themeDidChange;

@end

/**
 * An AwfulViewController is a thin customization of UIViewController that extends AwfulTheme support.
 *
 * AwfulViewController instances call -themeDidChange after loading their view, and they call -themeDidChange on all child view controllers and on the presented view controller.
 */
@interface AwfulViewController : UIViewController

/**
 * The theme to use for the view controller. Defaults to `[AwfulTheme currentTheme]`.
 */
@property (readonly, strong, nonatomic) AwfulTheme *theme;

@end

/**
 * An AwfulTableViewController is a thin customization of UITableViewController that extends AwfulTheme support.
 */
@interface AwfulTableViewController : UITableViewController 

/**
 * The theme to use for the view controller. Defaults to `[AwfulTheme currentTheme]`.
 */
@property (readonly, strong, nonatomic) AwfulTheme *theme;

@end

/**
 * An AwfulCollectionViewController is a thin customization of UICollectionViewController that extends AwfulTheme support.
 */
@interface AwfulCollectionViewController : UICollectionViewController 

/**
 * The theme to use for the view controller. Defaults to `[AwfulTheme currentTheme]`.
 */
@property (readonly, strong, nonatomic) AwfulTheme *theme;

@end
