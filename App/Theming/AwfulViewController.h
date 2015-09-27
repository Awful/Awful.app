//  AwfulViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class InfiniteTableController;
@class Theme;

@interface UIViewController (ThemeSupport)

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
@property (readonly, strong, nonatomic) Theme *theme;

/// Whether the view controller is currently visible (i.e. has received `viewDidAppear:` without having subsequently received `viewDidDisappear:`).
@property (readonly, assign, nonatomic) BOOL visible;

@end

/**
 * An AwfulTableViewController is a thin customization of UITableViewController that extends AwfulTheme support.
 */
@interface AwfulTableViewController : UITableViewController

/**
 * The theme to use for the view controller. Defaults to `[AwfulTheme currentTheme]`.
 */
@property (readonly, strong, nonatomic) Theme *theme;

/// Whether the view controller is currently visible (i.e. has received `viewDidAppear:` without having subsequently received `viewDidDisappear:`).
@property (readonly, assign, nonatomic) BOOL visible;

/// A block to call when the table is pulled down to refresh. If nil, no refresh control is shown.
@property (copy, nonatomic) void (^pullToRefreshBlock)(void);

/// A block to call when the table is pulled up to load more content. If nil, no load more control is shown.
@property (copy, nonatomic) void (^scrollToLoadMoreBlock)(void);

/// Returns the current infinite scroll controller, or nil if scrollToLoadMoreBlock is nil.
@property (readonly, nonatomic) InfiniteTableController *infiniteScrollController;

@end

/**
 * An AwfulCollectionViewController is a thin customization of UICollectionViewController that extends AwfulTheme support.
 */
@interface AwfulCollectionViewController : UICollectionViewController 

/**
 * The theme to use for the view controller. Defaults to `[AwfulTheme currentTheme]`.
 */
@property (readonly, strong, nonatomic) Theme *theme;

@end
