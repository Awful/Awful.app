//
//  AwfulVerticalTabBarController.h
//  Awful
//
//  Created by Nolan Waite on 2013-09-05.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * An AwfulVerticalTabBarController is a container view controller with a permanently visible tab bar along its left edge.
 */
@interface AwfulVerticalTabBarController : UIViewController

/**
 * Returns an initialized AwfulVerticalTabBarController.
 *
 * @param viewControllers An array of UIViewController objects.
 */
- (id)initWithViewControllers:(NSArray *)viewControllers;

/**
 * An array of UIViewController objects. They will be represented by their `tabBarItem`.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 * The selected view controller.
 */
@property (strong, nonatomic) UIViewController *selectedViewController;

@end
