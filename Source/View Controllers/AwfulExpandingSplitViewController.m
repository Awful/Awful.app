//  AwfulExpandingSplitViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulExpandingSplitViewController.h"

@interface AwfulExpandingSplitViewController () <UINavigationControllerDelegate>

@property (strong, nonatomic) NSLayoutConstraint *expandedDetailViewControllerConstraint;
@property (strong, nonatomic) UIView *divider;
@property (strong, nonatomic) UIView *fakeNavBar;

@end

@implementation AwfulExpandingSplitViewController
{
    NSMutableArray *_masterViewControllerConstraints;
    NSMutableArray *_detailViewControllerConstraints;
}

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _viewControllers = [viewControllers copy];
    return self;
}

- (void)loadView
{
    self.view = [UIView new];
    [self.view addSubview:self.divider];
    [self.view addSubview:self.fakeNavBar];
    NSDictionary *views = @{ @"divider": self.divider,
                             @"fakeNavBar": self.fakeNavBar };
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[fakeNavBar(64)][divider]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[fakeNavBar(divider)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    _masterViewControllerConstraints = [NSMutableArray new];
    _detailViewControllerConstraints = [NSMutableArray new];
    if (self.viewControllers.count > 0) {
        [self replaceMasterViewController:nil withViewController:self.viewControllers[0]];
    }
    if (self.detailViewController) {
        [self replaceDetailViewController:nil withViewController:self.detailViewController];
    }
}

- (UIView *)divider
{
    if (_divider) return _divider;
    _divider = [UIView new];
    _divider.translatesAutoresizingMaskIntoConstraints = NO;
    return _divider;
}

- (UIView *)fakeNavBar
{
    if (_fakeNavBar) return _fakeNavBar;
    _fakeNavBar = [UIView new];
    _fakeNavBar.translatesAutoresizingMaskIntoConstraints = NO;
    return _fakeNavBar;
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"splitViewBackgroundColor"];
    _divider.backgroundColor = self.theme[@"splitDividerColor"];
    self.fakeNavBar.backgroundColor = self.theme[@"navigationBarTintColor"];
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    if (_viewControllers == viewControllers) return;
    UIViewController *oldMasterViewController = _viewControllers[0];
    UIViewController *oldDetailViewController = self.detailViewController;
    _viewControllers = [viewControllers copy];
    [self ensureToggleDetailExpandedLeftBarButtonItem];
    if ([self isViewLoaded]) {
        UIViewController *newMasterViewController = _viewControllers[0];
        if (![oldMasterViewController isEqual:newMasterViewController]) {
            [self replaceMasterViewController:oldMasterViewController withViewController:newMasterViewController];
        }
        if (_viewControllers.count > 1) {
            [self replaceDetailViewController:oldDetailViewController withViewController:_viewControllers[1]];
        }
    }
}

- (void)ensureToggleDetailExpandedLeftBarButtonItem
{
    if ([self.detailViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *root = ((UINavigationController *)self.detailViewController).viewControllers.firstObject;
        [self ensureToggleDetailExpandedLeftBarButtonItemForViewController:root];
    } else {
        [self ensureToggleDetailExpandedLeftBarButtonItemForViewController:self.detailViewController];
    }
}

- (void)ensureToggleDetailExpandedLeftBarButtonItemForViewController:(UIViewController *)viewController
{
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self expandContractImage]
                                                                                       style:UIBarButtonItemStylePlain
                                                                                      target:self
                                                                                      action:@selector(toggleDetailExpanded)];
}

- (UIImage *)expandContractImage
{
    NSString *imageName = self.detailExpanded ? @"contract" : @"expand";
    return [UIImage imageNamed:imageName];
}

- (void)toggleDetailExpanded
{
    [self setDetailExpanded:!self.detailExpanded animated:YES];
}

- (void)replaceMasterViewController:(UIViewController *)oldMasterViewController
                 withViewController:(UIViewController *)newMasterViewController
{
    [oldMasterViewController willMoveToParentViewController:nil];
    [self addChildViewController:newMasterViewController];
    [self.view removeConstraints:_masterViewControllerConstraints];
    [_masterViewControllerConstraints removeAllObjects];
    [oldMasterViewController.view removeFromSuperview];
    newMasterViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    newMasterViewController.view.clipsToBounds = YES;
    [self.view insertSubview:newMasterViewController.view atIndex:0];
    NSDictionary *views = @{ @"master": newMasterViewController.view,
                             @"divider": self.divider,
                             @"fakeNavBar": self.fakeNavBar };
    [_masterViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[master][fakeNavBar(1)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_masterViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[master(383)][divider(1)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_masterViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[master]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_masterViewControllerConstraints];
    [oldMasterViewController removeFromParentViewController];
    [newMasterViewController didMoveToParentViewController:self];
    if (!self.detailExpanded) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)replaceDetailViewController:(UIViewController *)oldDetailViewController
                 withViewController:(UIViewController *)newDetailViewController
{
    if ([oldDetailViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)oldDetailViewController;
        if ([nav.delegate isEqual:self]) {
            nav.delegate = nil;
        }
    }
    if ([newDetailViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)newDetailViewController;
        if (!nav.delegate) {
            nav.delegate = self;
        }
    }
    [oldDetailViewController willMoveToParentViewController:nil];
    [self addChildViewController:newDetailViewController];
    [self.view removeConstraints:_detailViewControllerConstraints];
    [_detailViewControllerConstraints removeAllObjects];
    if (self.expandedDetailViewControllerConstraint) {
        [self.view removeConstraint:self.expandedDetailViewControllerConstraint];
        self.expandedDetailViewControllerConstraint = nil;
    }
    [oldDetailViewController.view removeFromSuperview];
    newDetailViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    newDetailViewController.view.clipsToBounds = YES;
    [self.view addSubview:newDetailViewController.view];
    UIViewController *master = self.viewControllers[0];
    NSDictionary *views = @{ @"master": master.view,
                             @"detail": newDetailViewController.view };
    [_detailViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[master]-1@500-[detail]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_detailViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[detail]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_detailViewControllerConstraints];
    if (self.detailExpanded) {
        [self constrainDetailViewExpanded];
    }
    [oldDetailViewController removeFromParentViewController];
    [newDetailViewController didMoveToParentViewController:self];
    if (self.detailExpanded) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)constrainDetailViewExpanded
{
    UIView *detail = self.detailViewController.view;
    self.expandedDetailViewControllerConstraint = [NSLayoutConstraint constraintWithItem:detail
                                                                               attribute:NSLayoutAttributeLeft
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeLeft
                                                                              multiplier:1
                                                                                constant:0];
    [self.view addConstraint:self.expandedDetailViewControllerConstraint];
}

- (void)setDetailExpanded:(BOOL)detailExpanded
{
    [self setDetailExpanded:detailExpanded animated:NO];
}

- (void)setDetailExpanded:(BOOL)detailExpanded animated:(BOOL)animated
{
    if (_detailExpanded == detailExpanded) return;
    _detailExpanded = detailExpanded;
    if (detailExpanded) {
        [self constrainDetailViewExpanded];
    } else {
        [self.view removeConstraint:self.expandedDetailViewControllerConstraint];
        self.expandedDetailViewControllerConstraint = nil;
    }
    [UIView animateWithDuration:(animated ? 0.3 : 0) animations:^{
        [self.view layoutIfNeeded];
    }];
    [self setNeedsStatusBarAppearanceUpdate];
    for (UINavigationController *navigationController in self.viewControllers) {
        if (![navigationController isKindOfClass:[UINavigationController class]]) continue;
        UIViewController *root = navigationController.viewControllers.firstObject;
        UIBarButtonItem *expandContractBarButtonItem = root.navigationItem.leftBarButtonItem;
        expandContractBarButtonItem.image = [self expandContractImage];
    }
}

- (UIViewController *)detailViewController
{
    return self.viewControllers.count > 1 ? self.viewControllers[1] : nil;
}

- (void)setDetailViewController:(UIViewController *)detailViewController
{
    if (detailViewController) {
        self.viewControllers = @[ self.viewControllers[0], detailViewController ];
    } else {
        self.viewControllers = @[ self.viewControllers[0] ];
    }
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    if (self.detailExpanded) {
        return self.detailViewController;
    } else {
        return self.viewControllers[0];
    }
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [navigationController setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
    [self ensureToggleDetailExpandedLeftBarButtonItemForViewController:viewController];
}

#pragma mark - State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.viewControllers forKey:ViewControllersKey];
    [coder encodeObject:self.detailViewController forKey:DetailViewControllerKey];
    [coder encodeBool:self.detailExpanded forKey:DetailExpandedKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.detailViewController = [coder decodeObjectForKey:DetailViewControllerKey];
    self.detailExpanded = [coder decodeBoolForKey:DetailExpandedKey];
}

- (void)applicationFinishedRestoringState
{
    [super applicationFinishedRestoringState];
    
    // If the detailViewController is a UINavigationController, it has no child view controllers as of -decodeRestorableStateWithCoder:. So it doesn't get its left bar button item set. That feels wrong to me, but this works if we do it here, so here we go.
    [self ensureToggleDetailExpandedLeftBarButtonItem];
}

static NSString * const ViewControllersKey = @"AwfulViewControllers";
static NSString * const DetailViewControllerKey = @"AwfulDetailViewController";
static NSString * const DetailExpandedKey = @"AwfulDetailExpanded";

@end

@implementation UIViewController (AwfulExpandingSplitViewController)

- (AwfulExpandingSplitViewController *)expandingSplitViewController
{
    UIViewController *maybe = self.parentViewController;
    while (maybe && ![maybe isKindOfClass:[AwfulExpandingSplitViewController class]]) {
        maybe = maybe.parentViewController;
    }
    return (AwfulExpandingSplitViewController *)maybe;
}

@end
