//  AwfulSplitViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSplitViewController.h"
#import "AwfulSplitView.h"

@interface AwfulSplitViewController () <AwfulSplitViewDelegate, UINavigationControllerDelegate>

@property (readonly, strong, nonatomic) AwfulSplitView *splitView;

@property (readonly, assign, nonatomic) BOOL sidebarShouldStickVisible;

@property (readonly, assign, nonatomic) UIInterfaceOrientationMask interfaceOrientationMask;

@property (strong, nonatomic) UIBarButtonItem *toggleSidebarHiddenItem;

@end

@implementation AwfulSplitViewController
{
    BOOL _whenLoadedSidebarHidden;
    BOOL _detailViewControllerIsInconsequential;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;
    _whenLoadedSidebarHidden = YES;
    _stickySidebarInterfaceOrientationMask = UIInterfaceOrientationMaskLandscape;
    return self;
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    [self setViewControllers:viewControllers animated:NO];
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    NSParameterAssert(viewControllers.count == 2);
    NSArray *oldViewControllers = _viewControllers;
    _viewControllers = [viewControllers copy];
    
    UIViewController *masterViewController = _viewControllers.firstObject;
    if ([masterViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)masterViewController;
        if (!navigationController.delegate) {
            navigationController.delegate = self;
        }
    }
    
    UIViewController *detailViewController = _viewControllers.lastObject;
    if ([detailViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)detailViewController;
        if (!navigationController.delegate) {
            navigationController.delegate = self;
        }
    }
    
    _detailViewControllerIsInconsequential = [detailViewController conformsToProtocol:@protocol(AwfulSplitViewControllerInconsequentialDetail)];
    if (!_detailViewControllerIsInconsequential && [detailViewController respondsToSelector:@selector(viewControllers)]) {
        UINavigationController *container = (UINavigationController *)detailViewController;
        UIViewController *first = container.viewControllers.firstObject;
        _detailViewControllerIsInconsequential = [first conformsToProtocol:@protocol(AwfulSplitViewControllerInconsequentialDetail)];
    }
    
    if ([self isViewLoaded]) {
        UIViewController *masterViewController = _viewControllers.firstObject;
        UIViewController *oldMasterViewController = oldViewControllers.firstObject;
        if (![masterViewController isEqual:oldMasterViewController]) {
            [oldMasterViewController willMoveToParentViewController:nil];
            [self addChildViewController:masterViewController];
            self.splitView.masterView = masterViewController.view;
            [oldMasterViewController removeFromParentViewController];
            [masterViewController didMoveToParentViewController:self];
        }
        
        UIViewController *oldDetailViewController = oldViewControllers.lastObject;
        if (![detailViewController isEqual:oldViewControllers.lastObject]) {
            if ([oldDetailViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = (UINavigationController *)oldDetailViewController;
                UIViewController *rootViewController = navigationController.viewControllers.firstObject;
                if ([rootViewController.navigationItem.leftBarButtonItem isEqual:self.toggleSidebarHiddenItem]) {
                    rootViewController.navigationItem.leftBarButtonItem = nil;
                }
            }
            [self updateToggleSidebarItemOnDetailViewController];
            
            [oldDetailViewController willMoveToParentViewController:nil];
            [self addChildViewController:detailViewController];
            [self.splitView setDetailView:detailViewController.view animated:animated];
            [oldDetailViewController removeFromParentViewController];
            [detailViewController didMoveToParentViewController:self];
            
            [self setNeedsStatusBarAppearanceUpdate];
            
            if (_detailViewControllerIsInconsequential) {
                [self setSidebarHidden:NO animated:animated];
            }
        }
    }
}

- (void)setDetailViewController:(UIViewController *)detailViewController sidebarHidden:(BOOL)sidebarHidden animated:(BOOL)animated
{
    NSMutableArray *viewControllers = [self.viewControllers mutableCopy];
    [viewControllers replaceObjectAtIndex:1 withObject:detailViewController];
    [self setViewControllers:viewControllers animated:animated];
    [self setSidebarHidden:sidebarHidden animated:animated];
}

- (void)setStickySidebarInterfaceOrientationMask:(UIInterfaceOrientationMask)stickySidebarInterfaceOrientationMask
{
    [self setStickySidebarInterfaceOrientationMask:stickySidebarInterfaceOrientationMask animated:NO];
}

- (void)setStickySidebarInterfaceOrientationMask:(UIInterfaceOrientationMask)stickySidebarInterfaceOrientationMask animated:(BOOL)animated
{
    _stickySidebarInterfaceOrientationMask = stickySidebarInterfaceOrientationMask;
    
    if ([self isViewLoaded]) {
        self.splitView.masterViewStuckVisible = self.sidebarShouldStickVisible;
        [self updateToggleSidebarItemOnDetailViewController];
        [self layoutSplitViewAnimated:animated];
    }
}

- (BOOL)sidebarHidden
{
    return [self isViewLoaded] ? self.splitView.masterViewHidden : _whenLoadedSidebarHidden;
}

- (void)setSidebarHidden:(BOOL)sidebarHidden
{
    [self setSidebarHidden:sidebarHidden animated:NO];
}

- (void)setSidebarHidden:(BOOL)sidebarHidden animated:(BOOL)animated
{
    if ([self isViewLoaded]) {
        BOOL wasHidden = self.splitView.masterViewHidden;
        if (!(sidebarHidden && _detailViewControllerIsInconsequential)) {
            self.splitView.masterViewHidden = sidebarHidden;
            [self layoutSplitViewAnimated:animated];
        }
        if (wasHidden != sidebarHidden) {
            UIViewController *interactingViewController;
            if (sidebarHidden) {
                interactingViewController = self.viewControllers.lastObject;
            } else {
                interactingViewController = self.viewControllers.firstObject;
            }
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, interactingViewController.view);
        }
    } else {
        _whenLoadedSidebarHidden = sidebarHidden;
    }
}

- (BOOL)sidebarShouldStickVisible
{
    return !!(self.interfaceOrientationMask & self.stickySidebarInterfaceOrientationMask);
}

- (UIInterfaceOrientationMask)interfaceOrientationMask
{
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationPortrait: return UIInterfaceOrientationMaskPortrait;
        case UIInterfaceOrientationLandscapeLeft: return UIInterfaceOrientationMaskLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight: return UIInterfaceOrientationMaskLandscapeRight;
        case UIInterfaceOrientationPortraitUpsideDown: return UIInterfaceOrientationMaskPortraitUpsideDown;
    }
}

- (void)layoutSplitViewAnimated:(BOOL)animated
{
    [self.view updateConstraintsIfNeeded];
    NSTimeInterval duration = animated ? 0.24 : 0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (UIBarButtonItem *)toggleSidebarHiddenItem
{
    if (_toggleSidebarHiddenItem) return _toggleSidebarHiddenItem;
    _toggleSidebarHiddenItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"hamburger-button"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(toggleSidebarHidden)];
    _toggleSidebarHiddenItem.accessibilityLabel = @"Sidebar";
    return _toggleSidebarHiddenItem;
}

- (void)toggleSidebarHidden
{
    [self setSidebarHidden:!self.sidebarHidden animated:YES];
}

- (void)updateToggleSidebarItemOnDetailViewController
{
    UIViewController *detailViewController = self.viewControllers.lastObject;
    if ([detailViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)detailViewController;
        UIViewController *rootViewController = navigationController.viewControllers.firstObject;
        UINavigationItem *navigationItem = rootViewController.navigationItem;
        if (self.sidebarShouldStickVisible) {
            navigationItem.leftBarButtonItem = nil;
        } else {
            navigationItem.leftBarButtonItem = self.toggleSidebarHiddenItem;
        }
    }
}

- (AwfulSplitView *)splitView
{
    return (AwfulSplitView *)self.view;
}

- (void)loadView
{
    self.view = [AwfulSplitView new];
    self.splitView.delegate = self;
    self.splitView.masterViewHidden = _whenLoadedSidebarHidden;
    
    UIViewController *masterViewController = self.viewControllers.firstObject;
    if (masterViewController) {
        [self addChildViewController:masterViewController];
        self.splitView.masterView = masterViewController.view;
        [masterViewController didMoveToParentViewController:self];
    }
    UIViewController *detailViewController = self.viewControllers.lastObject;
    if (detailViewController) {
        [self addChildViewController:detailViewController];
        self.splitView.detailView = detailViewController.view;
        [detailViewController didMoveToParentViewController:self];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.splitView.masterViewStuckVisible = self.sidebarShouldStickVisible;
    if (_detailViewControllerIsInconsequential) {
        self.sidebarHidden = NO;
    }
    [self updateToggleSidebarItemOnDetailViewController];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.splitView.masterViewStuckVisible = self.sidebarShouldStickVisible;
    if (_detailViewControllerIsInconsequential) {
        self.sidebarHidden = NO;
    }
    [self updateToggleSidebarItemOnDetailViewController];
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return self.viewControllers.lastObject;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.viewControllers.lastObject;
}

#pragma mark - AwfulSplitViewDelegate

- (void)splitViewDidTapDetailViewWhenMasterViewVisible:(AwfulSplitView *)splitView
{
    [self setSidebarHidden:YES animated:YES];
}

- (void)splitViewDidSwipeToShowMasterView:(AwfulSplitView *)splitView
{
    [self setSidebarHidden:NO animated:YES];
}

- (void)splitViewDidSwipeToPopNavigationController:(AwfulSplitView *)splitView
{
    // Search the master view controller hierarchy for a navigation controller to pop. It's OK if we don't find one, but we should try.
    UINavigationController *navigationController = self.viewControllers.firstObject;
    while (navigationController && ![navigationController isKindOfClass:[UINavigationController class]]) {
        if ([navigationController respondsToSelector:@selector(viewControllers)]) {
            navigationController = navigationController.viewControllers.firstObject;
        } else {
            navigationController = nil;
        }
    }
    [navigationController popViewControllerAnimated:YES];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [navigationController setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
}

#pragma mark - State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.viewControllers forKey:ViewControllersKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    NSArray *viewControllers = [coder decodeObjectForKey:ViewControllersKey];
    if (viewControllers.count > 0) {
        self.viewControllers = viewControllers;
    }
}

- (void)applicationFinishedRestoringState
{
    [super applicationFinishedRestoringState];
    
    // If the detail view controller is a UINavigationController, it has no child view controllers as of -decodeRestorableStateWithCoder:. So it doesn't get its left bar button item set. Seems lame, but if we do this stuff here then it works.
    [self updateToggleSidebarItemOnDetailViewController];
    if (!_detailViewControllerIsInconsequential) {
        self.sidebarHidden = YES;
    }
}

static NSString * const ViewControllersKey = @"AwfulViewControllers";

@end

@implementation UIViewController (AwfulSplitViewControllerAccess)

- (AwfulSplitViewController *)splitViewController
{
    UIViewController *candidate = self;
    while (candidate) {
        candidate = candidate.parentViewController;
        if ([candidate isKindOfClass:[AwfulSplitViewController class]]) {
            return (AwfulSplitViewController *)candidate;
        }
    }
    return nil;
}

@end
