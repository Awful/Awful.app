//  AwfulVerticalTabBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulVerticalTabBarDelegate;

/**
 * An AwfulVerticalTabBar implements selecting one of several items.
 */
@interface AwfulVerticalTabBar : UIView

/**
 * Returns an initialized AwfulVerticalTabBar. This is the designated initializer.
 *
 * @param items An array of UITabBarItem objects.
 */
- (id)initWithItems:(NSArray *)items;

/**
 * An array of UITabBarItem objects.
 */
@property (copy, nonatomic) NSArray *items;

/**
 * The currently selected item. No methods are called on the delegate as a result of setting this property.
 */
@property (strong, nonatomic) UITabBarItem *selectedItem;

/**
 * Additional distance to add between the top of the tab bar and the first tab. (Only the top inset is used.)
 */
@property (assign, nonatomic) UIEdgeInsets insets;

/**
 * The delegate.
 */
@property (weak, nonatomic) id <AwfulVerticalTabBarDelegate> delegate;

@end

/**
 * An AwfulVerticalTabBarDelegate is informed when the user selects an item.
 */
@protocol AwfulVerticalTabBarDelegate <NSObject>

/**
 * Informs the delegate that the user selected an item. It's possible that the item was already the selected one.
 *
 * @param tabBar The tab bar whose item was selected.
 * @param item The selected item. Use the tab bar's `items` property to obtain an index.
 */
- (void)tabBar:(AwfulVerticalTabBar *)tabBar didSelectItem:(UITabBarItem *)item;

@end
