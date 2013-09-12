//  AwfulVerticalTabBarController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulVerticalTabBarController.h"
#import "AwfulVerticalTabBar.h"

@interface AwfulVerticalTabBarController () <AwfulVerticalTabBarDelegate>

@property (strong, nonatomic) AwfulVerticalTabBar *tabBar;

@end

@implementation AwfulVerticalTabBarController
{
    NSMutableArray *_selectedViewControllerConstraints;
}

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:Nil bundle:nil])) return nil;
    self.viewControllers = viewControllers;
    _selectedViewControllerConstraints = [NSMutableArray new];
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
    UIViewController *oldViewController = _selectedViewController;
    _selectedViewController = selectedViewController;
    if ([self isViewLoaded]) {
        [self replaceMainViewController:oldViewController withViewController:_selectedViewController];
        self.tabBar.selectedItem = _selectedViewController.tabBarItem;
    }
}

- (NSUInteger)selectedIndex
{
    return [self.viewControllers indexOfObject:self.selectedViewController];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    self.selectedViewController = self.viewControllers[selectedIndex];
}

- (void)loadView
{
    self.view = [UIView new];
    NSArray *tabBarItems = [self.viewControllers valueForKey:@"tabBarItem"];
    self.tabBar = [[AwfulVerticalTabBar alloc] initWithItems:tabBarItems];
    self.tabBar.delegate = self;
    self.tabBar.selectedItem = self.selectedViewController.tabBarItem;
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBar.tintColor = [UIColor colorWithRed:0.078 green:0.514 blue:0.694 alpha:1];
    [self.view addSubview:self.tabBar];
    NSDictionary *views = @{ @"tabBar": self.tabBar,
                             @"top": self.topLayoutGuide };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tabBar(==64)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[top]-[tabBar]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self replaceMainViewController:nil withViewController:self.selectedViewController];
}

- (void)replaceMainViewController:(UIViewController *)oldViewController
               withViewController:(UIViewController *)newViewController
{
    [oldViewController willMoveToParentViewController:nil];
    [self addChildViewController:newViewController];
    [self.view removeConstraints:_selectedViewControllerConstraints];
    [_selectedViewControllerConstraints removeAllObjects];
    [oldViewController.view removeFromSuperview];
    newViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:newViewController.view];
    NSDictionary *views = @{ @"tabBar": self.tabBar,
                             @"main": newViewController.view };
    [_selectedViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"[tabBar][main]|" options:0 metrics:nil views:views]];
    [_selectedViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[main]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_selectedViewControllerConstraints];
    [oldViewController removeFromParentViewController];
    [newViewController didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.selectedViewController;
}

#pragma mark AwfulVerticalTabBarControllerDelegate

- (void)tabBar:(AwfulVerticalTabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    self.selectedIndex = [tabBar.items indexOfObject:item];
}

@end
