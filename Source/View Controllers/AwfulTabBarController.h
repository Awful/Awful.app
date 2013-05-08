//
//  AwfulTabBarController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulTabBar.h"
@protocol AwfulTabBarControllerDelegate;

// A custom tab bar controller so we can make the tabs look however we want.
@interface AwfulTabBarController : UIViewController

// This tab bar controller differs from UITabBarController in the following ways:
//
//   - Its tab bar is an instance of AwfulTabBar.
//   - There's no More item. (All items are always shown.)
//   - The tab bar is hidden if and only if the topmost view controller of a navigation stack
//     returns NO from -hidesBottomBarWhenPushed. (UITabBarController hides the tab bar if *any*
//     view controller in a navigation stack returns NO.)
//       - The animation when hiding or showing the tab bar after popping a view controller looks
//         shitty because we don't know whether the view controller is being popped or pushed.

// Designated initializer.
- (id)initWithViewControllers:(NSArray *)viewControllers;

@property (readonly, copy, nonatomic) NSArray *viewControllers;

@property (weak, nonatomic) UIViewController *selectedViewController;

@property (weak, nonatomic) id <AwfulTabBarControllerDelegate> delegate;

// For presenting action sheets.
@property (readonly, nonatomic) AwfulTabBar *tabBar;

@end


@protocol AwfulTabBarControllerDelegate <NSObject>

- (BOOL)tabBarController:(AwfulTabBarController *)controller
shouldSelectViewController:(UIViewController *)viewController;

@end


@interface UIViewController (AwfulTabBarController)

@property (readonly, nonatomic) AwfulTabBarController *awfulTabBarController;

@end
