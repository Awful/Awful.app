//  AwfulBasementSidebarViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
@protocol AwfulBasementSidebarViewControllerDelegate;

/**
 * An AwfulBasementSidebarViewController is created by an AwfulBasementViewController to list the available view controllers.
 */
@interface AwfulBasementSidebarViewController : AwfulTableViewController

/**
 * An array of UITabBarItem objects.
 */
@property (copy, nonatomic) NSArray *items;

/**
 * The currently-selected item. No delegate methods are called as a result of setting this property.
 */
@property (strong, nonatomic) UITabBarItem *selectedItem;

/**
 * The delegate.
 */
@property (weak, nonatomic) id <AwfulBasementSidebarViewControllerDelegate> delegate;

@end

/**
 * An AwfulBasementSidebarViewControllerDelegate is informed of user changes to the selected item in an AwfulBasementSidebarViewController.
 */
@protocol AwfulBasementSidebarViewControllerDelegate <NSObject>

/**
 * Informs the delegate that the user has tapped an item.
 *
 * @param sidebar The sidebar whose item was tapped.
 * @param item The newly-selected item. Obtain its index using the sidebar's `items` array.
 */
- (void)sidebar:(AwfulBasementSidebarViewController *)sidebar didSelectItem:(UITabBarItem *)item;

@end
