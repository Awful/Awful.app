//
//  AwfulTabBarController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulTabBarController.h"
#import "AwfulTabBar.h"

@interface AwfulTabBarController () <AwfulTabBarDelegate, UINavigationControllerDelegate>

@property (copy, nonatomic) NSArray *viewControllers;
@property (nonatomic) AwfulTabBar *tabBar;

@end


@interface AwfulTabBarControllerContentView : UIView

@property (weak, nonatomic) UIView *tabBar;

@end


@implementation AwfulTabBarController

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.viewControllers = [viewControllers copy];
    for (UINavigationController *nav in self.viewControllers) {
        if ([nav isKindOfClass:[UINavigationController class]]) {
            nav.delegate = self;
        }
    }
    self.selectedViewController = self.viewControllers[0];
    return self;
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
    if (_selectedViewController == selectedViewController) return;
    UIViewController *old = _selectedViewController;
    _selectedViewController = selectedViewController;
    self.tabBar.selectedItem = selectedViewController.tabBarItem;
    if (![self isViewLoaded]) return;
    [old willMoveToParentViewController:nil];
    [self addViewController:selectedViewController];
    [old.view removeFromSuperview];
    [old removeFromParentViewController];
}

- (void)addViewController:(UIViewController *)coming
{
    [self addChildViewController:coming];
    coming.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight);
    [self.view insertSubview:coming.view belowSubview:self.tabBar];
    [self layoutSelectedViewControllerViewAndTabBar];
    [coming didMoveToParentViewController:self];
}

- (void)layoutSelectedViewControllerViewAndTabBar
{
    CGRect viewFrame, tabBarFrame;
    CGRectDivide(self.view.bounds, &tabBarFrame, &viewFrame, CGRectGetHeight(self.tabBar.bounds),
                 CGRectMaxYEdge);
    if (self.tabBar.hidden) {
        viewFrame = CGRectUnion(viewFrame, tabBarFrame);
        tabBarFrame.origin.x -= CGRectGetWidth(tabBarFrame);
    }
    self.selectedViewController.view.frame = viewFrame;
    self.tabBar.frame = tabBarFrame;
}

#pragma mark - UIViewController

- (void)loadView
{
    AwfulTabBarControllerContentView *contentView = [AwfulTabBarControllerContentView new];
    self.view = contentView;
    self.view.frame = [UIScreen mainScreen].applicationFrame;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.clipsToBounds = YES;
    
    self.tabBar = [[AwfulTabBar alloc] initWithFrame:CGRectMake(0, 0, 0, 38)];
    self.tabBar.items = [self.viewControllers valueForKey:@"tabBarItem"];
    self.tabBar.selectedItem = self.selectedViewController.tabBarItem;
    self.tabBar.delegate = self;
    self.tabBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleTopMargin);
    [self.view addSubview:self.tabBar];
    contentView.tabBar = self.tabBar;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.selectedViewController) {
        [self addViewController:self.selectedViewController];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self layoutSelectedViewControllerViewAndTabBar];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    for (UIViewController *viewController in self.viewControllers) {
        if (![viewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation]) {
            return NO;
        }
    }
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self layoutSelectedViewControllerViewAndTabBar];
}

- (UIView *)rotatingFooterView
{
    return self.tabBar.hidden ? nil : self.tabBar;
}

#pragma mark - AwfulTabBarDelegate

- (void)tabBar:(AwfulTabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    UIViewController *selected = self.viewControllers[[tabBar.items indexOfObject:item]];
    if (![self.delegate tabBarController:self shouldSelectViewController:selected]) {
        self.tabBar.selectedItem = self.selectedViewController.tabBarItem;
        return;
    }
    if ([selected isEqual:self.selectedViewController]) {
        if ([selected isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (id)selected;
            if ([nav.viewControllers count] > 1) {
                [(UINavigationController *)selected popToRootViewControllerAnimated:YES];
            } else if ([nav.topViewController.view isKindOfClass:[UIScrollView class]]) {
                UIScrollView *scrollView = (id)nav.topViewController.view;
                [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top)
                                    animated:YES];
            }
        }
    } else {
        self.selectedViewController = selected;
    }
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (viewController.hidesBottomBarWhenPushed && !self.tabBar.hidden) {
        self.selectedViewController.view.frame = (CGRect){ .size = self.view.bounds.size };
        CGRect tabBarFrame = CGRectOffset(self.tabBar.frame, -self.tabBar.bounds.size.width, 0);
        if (animated) {
            [UIView animateWithDuration:0.34
                                  delay:0
                                options:(UIViewAnimationOptionLayoutSubviews |
                                         UIViewAnimationOptionCurveEaseIn)
                             animations:^
             {
                 self.tabBar.frame = tabBarFrame;
             } completion:^(BOOL finished) {
                 self.tabBar.hidden = YES;
             }];
        } else {
            self.tabBar.frame = tabBarFrame;
            self.tabBar.hidden = YES;
        }
    } else if (!viewController.hidesBottomBarWhenPushed && self.tabBar.hidden) {
        self.tabBar.hidden = NO;
        CGRect tabBarFrame, containedFrame;
        CGRectDivide(self.view.bounds, &tabBarFrame, &containedFrame,
                     self.tabBar.bounds.size.height, CGRectMaxYEdge);
        if (animated) {
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:(UIViewAnimationOptionLayoutSubviews |
                                         UIViewAnimationOptionCurveEaseIn)
                             animations:^{
                                 self.tabBar.frame = tabBarFrame;
                             } completion:^(BOOL finished) {
                                 [UIView animateWithDuration:0.1
                                                       delay:0
                                                     options:(UIViewAnimationOptionLayoutSubviews |
                                                              UIViewAnimationOptionCurveEaseIn)
                                                  animations:^
                                 {
                                     self.selectedViewController.view.frame = containedFrame;
                                 } completion:nil];
                             }];
        } else {
            self.tabBar.frame = tabBarFrame;
            self.selectedViewController.view.frame = containedFrame;
        }
    }
}

@end


@implementation AwfulTabBarControllerContentView

#pragma mark - UIView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // Give the tab bar a 44pt tall hitbox.
    if (self.tabBar && !self.tabBar.hidden && self.tabBar.alpha >= 0.01) {
        CGRect hitbox = self.tabBar.frame;
        CGFloat delta = 44 - CGRectGetHeight(hitbox);
        if (delta > 0) {
            hitbox.origin.y -= delta;
            hitbox.size.height += delta;
        }
        if (CGRectContainsPoint(hitbox, point)) {
            return [self.tabBar hitTest:[self.tabBar convertPoint:point fromView:self]
                              withEvent:event];
        }
    }
    return [super hitTest:point withEvent:event];
}

@end


@implementation UIViewController (AwfulTabBarController)

- (AwfulTabBarController *)awfulTabBarController
{
    UIViewController *vc = self;
    while (vc && ![vc isKindOfClass:[AwfulTabBarController class]]) {
        vc = vc.parentViewController;
    }
    return (AwfulTabBarController *)vc;
}

@end
