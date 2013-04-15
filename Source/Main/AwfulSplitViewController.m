//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-15.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulSplitViewController.h"
#import "AwfulTabBarController.h"

@interface AwfulSplitViewController ()

@property (nonatomic) UIViewController *sidebarViewController;
@property (nonatomic) UIViewController *mainViewController;
@property (nonatomic) UIView *sidebarHolder;
@property (nonatomic) UIView *coverView;
@property (nonatomic) UISwipeGestureRecognizer *mainSwipeRight;

@end


@implementation AwfulSplitViewController

- (instancetype)initWithSidebarViewController:(UIViewController *)sidebarViewController
                           mainViewController:(UIViewController *)mainViewController
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _sidebarViewController = sidebarViewController;
    _mainViewController = mainViewController;
    return self;
}

- (void)setSidebarVisible:(BOOL)show
{
    [self setSidebarVisible:show animated:NO];
}

- (void)setSidebarVisible:(BOOL)show animated:(BOOL)animated
{
    if (_sidebarVisible == show) return;
    if (!show && !self.sidebarCanHide) return;
    _sidebarVisible = show;
    if (show) {
        if (self.sidebarCanHide) {
            self.coverView.frame = self.view.bounds;
            [self.view addSubview:self.coverView];
        }
        [self addChildViewController:self.sidebarViewController];
        [self.view addSubview:self.sidebarHolder];
    } else {
        [self.sidebarViewController willMoveToParentViewController:nil];
        [self.coverView removeFromSuperview];
    }
    [UIView animateWithDuration:animated ? 0.25 : 0 animations:^{
        [self layoutViewControllers];
    } completion:^(BOOL finished) {
        if (!finished) return;
        if (show) {
            [self.sidebarViewController didMoveToParentViewController:self];
        } else {
            [self.sidebarHolder removeFromSuperview];
            [self.sidebarViewController removeFromParentViewController];
        }
    }];
}

- (UIView *)coverView
{
    if (_coverView) return _coverView;
    _coverView = [UIView new];
    UISwipeGestureRecognizer *swipeLeft = [UISwipeGestureRecognizer new];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [swipeLeft addTarget:self action:@selector(didSwipeLeftOnCoverView)];
    [_coverView addGestureRecognizer:swipeLeft];
    UISwipeGestureRecognizer *swipeRight = [UISwipeGestureRecognizer new];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [swipeRight addTarget:self action:@selector(didSwipeRightOnCoverView)];
    [_coverView addGestureRecognizer:swipeRight];
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(didTapCoverView:)];
    [_coverView addGestureRecognizer:tap];
    return _coverView;
}

- (void)didSwipeLeftOnCoverView
{
    [self setSidebarVisible:NO animated:YES];
}

- (void)didSwipeRightOnCoverView
{
    UINavigationController *nav = (id)self.sidebarViewController;
    if ([nav isKindOfClass:[AwfulTabBarController class]]) {
        nav = (id)[(UITabBarController *)nav selectedViewController];
    }
    if ([nav isKindOfClass:[UINavigationController class]]) {
        [nav popViewControllerAnimated:YES];
    }
}

- (void)didTapCoverView:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded) return;
    [self setSidebarVisible:NO animated:YES];
}

- (void)setSidebarCanHide:(BOOL)canHide
{
    if (_sidebarCanHide == canHide) return;
    _sidebarCanHide = canHide;
    [self layoutViewControllers];
    if (canHide) {
        self.sidebarHolder.layer.shadowOpacity = 0.5;
        [self.mainViewController.view addGestureRecognizer:self.mainSwipeRight];
    } else {
        self.sidebarHolder.layer.shadowOpacity = 0;
        self.sidebarVisible = YES;
        [self.mainViewController.view removeGestureRecognizer:self.mainSwipeRight];
    }
}

- (UISwipeGestureRecognizer *)mainSwipeRight
{
    if (_mainSwipeRight) return _mainSwipeRight;
    _mainSwipeRight = [UISwipeGestureRecognizer new];
    _mainSwipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [_mainSwipeRight addTarget:self action:@selector(didSwipeRightOnMainView)];
    return _mainSwipeRight;
}

- (void)didSwipeRightOnMainView
{
    [self setSidebarVisible:YES animated:YES];
}

- (void)layoutViewControllers
{
    const CGFloat sidebarWidth = 320;
    CALayer *sidebarLayer = self.sidebarHolder.layer;
    if (sidebarLayer.shadowOpacity > 0) {
        sidebarLayer.shadowPath = [UIBezierPath bezierPathWithRect:sidebarLayer.bounds].CGPath;
    }
    if (self.sidebarCanHide) {
        self.mainViewController.view.frame = self.view.bounds;
        CGRect sidebarFrame = CGRectMake(0, 0, sidebarWidth, CGRectGetHeight(self.view.bounds));
        if (!self.sidebarVisible) {
            sidebarFrame.origin.x -= CGRectGetWidth(sidebarFrame) + 3;
        }
        self.sidebarHolder.frame = sidebarFrame;
    } else {
        CGRect sidebarFrame, mainFrame;
        CGRectDivide(self.view.bounds, &sidebarFrame, &mainFrame, sidebarWidth, CGRectMinXEdge);
        mainFrame.origin.x += 1;
        mainFrame.size.width -= 1;
        self.sidebarHolder.frame = sidebarFrame;
        self.mainViewController.view.frame = mainFrame;
    }
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor blackColor];
    
    const CGFloat cornerRadius = 4;
    
    self.sidebarHolder = [UIView new];
    self.sidebarHolder.layer.shadowOffset = CGSizeMake(3, 0);
    self.sidebarViewController.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                                        UIViewAutoresizingFlexibleHeight);
    self.sidebarViewController.view.frame = self.sidebarHolder.bounds;
    self.sidebarViewController.view.layer.cornerRadius = cornerRadius;
    [self.sidebarHolder addSubview:self.sidebarViewController.view];
    
    [self layoutViewControllers];
    
    [self addChildViewController:self.mainViewController];
    self.mainViewController.view.layer.cornerRadius = cornerRadius;
    self.mainViewController.view.clipsToBounds = YES;
    [self.view addSubview:self.mainViewController.view];
    [self.mainViewController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setSidebarCanHide:[self shouldHideSidebar]];
    [self.delegate awfulSplitViewController:self willHideSidebar:self.sidebarCanHide];
}

- (BOOL)shouldHideSidebar
{
    return [self.delegate awfulSplitViewController:self
                    shouldHideSidebarInOrientation:self.interfaceOrientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return [self.mainViewController shouldAutorotateToInterfaceOrientation:orientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration
{
    [self setSidebarCanHide:[self shouldHideSidebar]];
    if (self.sidebarCanHide) {
        self.sidebarVisible = NO;
    }
    [self layoutViewControllers];
    [self.delegate awfulSplitViewController:self willHideSidebar:self.sidebarCanHide];
}

@end


@implementation UIViewController (AwfulSplitViewController)

- (AwfulSplitViewController *)awfulSplitViewController
{
    UIViewController *vc = self;
    do {
        vc = vc.parentViewController;
    } while (vc && ![vc isKindOfClass:[AwfulSplitViewController class]]);
    return (id)vc;
}

@end
