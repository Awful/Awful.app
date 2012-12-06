//
//  AwfulTabBarController.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
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

@property (copy, nonatomic) NSArray *viewControllers;

@property (weak, nonatomic) UIViewController *selectedViewController;

@property (weak, nonatomic) id <AwfulTabBarControllerDelegate> delegate;

// For presenting action sheets.
@property (readonly, weak, nonatomic) AwfulTabBar *tabBar;

@end


@protocol AwfulTabBarControllerDelegate <NSObject>
@optional

- (BOOL)tabBarController:(AwfulTabBarController *)controller
    shouldSelectViewController:(UIViewController *)viewController;

@end


@interface UIViewController (AwfulTabBarController)

@property (readonly, nonatomic) AwfulTabBarController *awfulTabBarController;

@end
