//  AwfulBasementViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBasementViewController.h"
#import "AwfulBasementSidebarViewController.h"

/**
 * An AwfulBasementViewController operates a state machine between three states with the following transitions:
 *
 * Hidden <----> Obscured <----> Visible
 */
typedef NS_ENUM(NSInteger, AwfulBasementSidebarState)
{
    /**
     * When the sidebar is hidden, the selected view controller fills the entire view.
     */
    AwfulBasementSidebarStateHidden,
    
    /**
     * The sidebar is obscured when the selected view controller is being dragged around.
     */
    AwfulBasementSidebarStateObscured,
    
    /**
     * When the sidebar is visible, user interaction is disabled on the selected view controller's view.
     */
    AwfulBasementSidebarStateVisible,
};

@interface AwfulBasementViewController () <AwfulBasementSidebarViewControllerDelegate, UIGestureRecognizerDelegate>

@property (assign, nonatomic) AwfulBasementSidebarState state;
@property (strong, nonatomic) AwfulBasementSidebarViewController *sidebarViewController;
@property (strong, nonatomic) UIView *mainContainerView;
@property (strong, nonatomic) NSLayoutConstraint *revealSidebarConstraint;
@property (copy, nonatomic) NSArray *selectedViewControllerConstraints;
@property (copy, nonatomic) NSArray *visibleSidebarConstraints;
@property (strong, nonatomic) UIPanGestureRecognizer *mainViewPan;
@property (strong, nonatomic) UITapGestureRecognizer *mainViewTap;

@end

@implementation AwfulBasementViewController

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.viewControllers = viewControllers;
    return self;
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    if (_viewControllers == viewControllers) return;
    _viewControllers = [viewControllers copy];
    self.sidebarViewController.items = [_viewControllers valueForKey:@"tabBarItem"];
    for (UIViewController *viewController in _viewControllers) {
        UINavigationItem *navigationItem = viewController.navigationItem;
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UIViewController *root = ((UINavigationController *)viewController).viewControllers[0];
            navigationItem = root.navigationItem;
        }
        navigationItem.leftBarButtonItem = [self createShowSidebarItem];
    }
    if (![_viewControllers containsObject:self.selectedViewController]) {
        self.selectedViewController = _viewControllers[0];
    }
}

- (UIBarButtonItem *)createShowSidebarItem
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                                                         target:self
                                                         action:@selector(showSidebar)];
}

- (void)showSidebar
{
    [self setSidebarVisible:YES animated:YES];
}

- (void)loadView
{
    self.view = [UIView new];
    self.sidebarViewController = [AwfulBasementSidebarViewController new];
    self.sidebarViewController.delegate = self;
    self.sidebarViewController.items = [self.viewControllers valueForKey:@"tabBarItem"];
    self.sidebarViewController.selectedItem = self.selectedViewController.tabBarItem;
    
    UIScreenEdgePanGestureRecognizer *pan = [UIScreenEdgePanGestureRecognizer new];
    pan.edges = UIRectEdgeLeft;
    [pan addTarget:self action:@selector(panFromLeftScreenEdge:)];
    [self.view addGestureRecognizer:pan];
    
    self.mainContainerView = [UIView new];
    self.mainContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mainContainerView];
    
    [self replaceMainViewController:nil withViewController:self.selectedViewController];
}

- (void)panFromLeftScreenEdge:(UIScreenEdgePanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.state = AwfulBasementSidebarStateObscured;
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        if ([pan velocityInView:self.view].x > 0) {
            [self setState:AwfulBasementSidebarStateVisible animated:YES];
        } else {
            [self setState:AwfulBasementSidebarStateHidden animated:YES];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSDictionary *views = @{ @"root": self.view,
                             @"main": self.mainContainerView };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0@500-[main(==root)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[main]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    if (self.sidebarVisible) {
        [self constrainSidebarToBeVisible];
        [self.view setNeedsLayout];
    }
}

- (void)constrainSidebarToBeVisible
{
    if (self.visibleSidebarConstraints) return;
    NSDictionary *views = @{ @"sidebar": self.sidebarViewController.view,
                             @"main": self.mainContainerView };
    self.visibleSidebarConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sidebar][main]"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views];
    [self.view addConstraints:self.visibleSidebarConstraints];
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
    UIViewController *old = _selectedViewController;
    _selectedViewController = selectedViewController;
    if ([self isViewLoaded] && ![old isEqual:selectedViewController]) {
        [self replaceMainViewController:old withViewController:selectedViewController];
    }
}

- (void)replaceMainViewController:(UIViewController *)oldViewController
               withViewController:(UIViewController *)newViewController
{
    [oldViewController willMoveToParentViewController:nil];
    [self addChildViewController:newViewController];
    if (self.selectedViewControllerConstraints) {
        [self.mainContainerView removeConstraints:self.selectedViewControllerConstraints];
    }
    [oldViewController.view removeFromSuperview];
    newViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainContainerView addSubview:newViewController.view];
    NSMutableArray *constraints = [NSMutableArray new];
    NSDictionary *views = @{ @"new": newViewController.view };
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[new]|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[new]|" options:0 metrics:nil views:views]];
    self.selectedViewControllerConstraints = constraints;
    [self.mainContainerView addConstraints:constraints];
    [oldViewController removeFromParentViewController];
    [newViewController didMoveToParentViewController:self];
}

- (BOOL)sidebarVisible
{
    return self.state != AwfulBasementSidebarStateHidden;
}

- (void)setSidebarVisible:(BOOL)sidebarVisible
{
    [self setSidebarVisible:sidebarVisible animated:NO];
}

- (void)setSidebarVisible:(BOOL)sidebarVisible animated:(BOOL)animated
{
    if (sidebarVisible) {
        [self setState:AwfulBasementSidebarStateVisible animated:animated];
    } else {
        [self setState:AwfulBasementSidebarStateHidden animated:animated];
    }
}

- (void)setState:(AwfulBasementSidebarState)state
{
    [self setState:state animated:NO];
}

- (void)setState:(AwfulBasementSidebarState)state animated:(BOOL)animated
{
    if (_state == state) return;
    _state = state;
    if (![self isViewLoaded]) return;
    
    if (state == AwfulBasementSidebarStateHidden) {
        if (self.revealSidebarConstraint) {
            [self.view removeConstraint:self.revealSidebarConstraint];
            self.revealSidebarConstraint = nil;
        }
        if (self.visibleSidebarConstraints) {
            [self.view removeConstraints:self.visibleSidebarConstraints];
            self.visibleSidebarConstraints = nil;
        }
        self.mainContainerView.userInteractionEnabled = YES;
    } else {
        [self lazilyAddSidebarViewControllerAsChild];
        self.mainContainerView.userInteractionEnabled = NO;
    }
    
    if (state == AwfulBasementSidebarStateObscured) {
        if (self.visibleSidebarConstraints) {
            [self.view removeConstraints:self.visibleSidebarConstraints];
            self.visibleSidebarConstraints = nil;
        }
        self.revealSidebarConstraint = [NSLayoutConstraint constraintWithItem:self.mainContainerView
                                                                    attribute:NSLayoutAttributeLeft
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:self.view
                                                                    attribute:NSLayoutAttributeLeft
                                                                   multiplier:1
                                                                     constant:0];
        self.revealSidebarConstraint.priority = 750;
        [self.view addConstraint:self.revealSidebarConstraint];
    } else {
        if (self.mainViewPan) {
            [self.mainViewPan.view removeGestureRecognizer:self.mainViewPan];
            self.mainViewPan = nil;
        }
    }
    
    if (state == AwfulBasementSidebarStateVisible) {
        if (self.revealSidebarConstraint) {
            [self.view removeConstraint:self.revealSidebarConstraint];
            self.revealSidebarConstraint = nil;
        }
        [self constrainSidebarToBeVisible];
        self.mainViewTap = [UITapGestureRecognizer new];
        self.mainViewTap.delegate = self;
        [self.mainViewTap addTarget:self action:@selector(tapMainView:)];
        [self.view addGestureRecognizer:self.mainViewTap];
        self.mainViewPan = [UIPanGestureRecognizer new];
        [self.mainViewPan addTarget:self action:@selector(panMainView:)];
        [self.view addGestureRecognizer:self.mainViewPan];
    } else {
        if (self.mainViewTap) {
            [self.mainViewTap.view removeGestureRecognizer:self.mainViewTap];
            self.mainViewTap = nil;
        }
    }
    
    [UIView animateWithDuration:(animated ? 0.2 : 0) animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)lazilyAddSidebarViewControllerAsChild
{
    if ([self.sidebarViewController.parentViewController isEqual:self]) return;
    [self addChildViewController:self.sidebarViewController];
    self.sidebarViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.sidebarViewController.view belowSubview:self.mainContainerView];
    [self.sidebarViewController didMoveToParentViewController:self];
    NSDictionary *views = @{ @"sidebar": self.sidebarViewController.view,
                             @"top": self.topLayoutGuide };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sidebar(==280)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[top][sidebar]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
}

- (void)tapMainView:(UITapGestureRecognizer *)tap
{
    if (CGRectContainsPoint(self.mainContainerView.frame, [tap locationInView:self.view])) {
        [self setSidebarVisible:NO animated:YES];
    }
}

- (void)panMainView:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        if (!(CGRectContainsPoint(self.mainContainerView.frame, [pan locationInView:self.view]))) {
            // Cancel the pan.
            pan.enabled = NO;
            pan.enabled = YES;
            return;
        }
        CGPoint start = CGPointMake(CGRectGetMinX(self.mainContainerView.frame), 0);
        start.x += [pan translationInView:pan.view].x;
        [pan setTranslation:start inView:self.view];
        self.state = AwfulBasementSidebarStateObscured;
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        if ([pan velocityInView:self.view].x > 0) {
            [self setState:AwfulBasementSidebarStateVisible animated:YES];
        } else {
            [self setState:AwfulBasementSidebarStateHidden animated:YES];
        }
    }
}

#pragma mark AwfulBasementSidebarViewControllerDelegate

- (void)sidebar:(AwfulBasementSidebarViewController *)sidebar didSelectItem:(UITabBarItem *)item
{
    NSUInteger i = [sidebar.items indexOfObject:item];
    self.selectedViewController = self.viewControllers[i];
    [self setSidebarVisible:NO animated:YES];
}

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return CGRectContainsPoint(self.mainContainerView.frame, [touch locationInView:self.view]);
}

@end
