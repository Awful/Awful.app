//
//  AwfulVerticalTabBarController.m
//  Awful
//
//  Created by Nolan Waite on 2013-09-05.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulVerticalTabBarController.h"
#import "AwfulVerticalTabBar.h"

@interface AwfulVerticalTabBarController ()

@property (strong, nonatomic) AwfulVerticalTabBar *tabBar;
@property (copy, nonatomic) NSArray *selectedViewControllerConstraints;

@end

@implementation AwfulVerticalTabBarController

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:Nil bundle:nil])) return nil;
    self.viewControllers = viewControllers;
    return self;
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    if (_viewControllers == viewControllers) return;
    _viewControllers = [viewControllers copy];
    if (![_viewControllers containsObject:self.selectedViewController]) {
        self.selectedViewController = _viewControllers[0];
    }
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
    if (_selectedViewController == selectedViewController) return;
    _selectedViewController = selectedViewController;
    
}

- (void)loadView
{
    self.view = [UIView new];
    NSArray *tabBarItems = [self.viewControllers valueForKey:@"tabBarItem"];
    self.tabBar = [[AwfulVerticalTabBar alloc] initWithItems:tabBarItems];
    self.tabBar.selectedItem = self.selectedViewController.tabBarItem;
    [self.view addSubview:self.tabBar];
    NSDictionary *views = @{ @"tabBar": self.tabBar };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tabBar(==64)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tabBar]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
}

- (void)replaceMainViewController:(UIViewController *)oldViewController
               withViewController:(UIViewController *)newViewController
{
    [oldViewController willMoveToParentViewController:nil];
    [self addChildViewController:newViewController];
    if (self.selectedViewControllerConstraints) {
        [self.view removeConstraints:self.selectedViewControllerConstraints];
    }
    [oldViewController.view removeFromSuperview];
    newViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:newViewController.view];
    NSMutableArray *constraints = [NSMutableArray new];
    NSDictionary *views = @{ @"tabBar": self.tabBar,
                             @"main": newViewController.view };
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[tabBar][main]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[main]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    self.selectedViewControllerConstraints = constraints;
    [self.view addConstraints:self.selectedViewControllerConstraints];
    [oldViewController removeFromParentViewController];
    [newViewController didMoveToParentViewController:self];
}

@end
