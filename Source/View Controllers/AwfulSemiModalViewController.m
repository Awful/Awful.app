//  AwfulSemiModalViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
#import "AwfulHoleyDimmingView.h"

@interface AwfulSemiModalViewController () <UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIPopoverControllerDelegate>

@property (weak, nonatomic) UIView *contextView;

@property (copy, nonatomic) AwfulSemiModalRectInViewBlock regionBlock;

@property (weak, nonatomic) UIViewController *directlyPresentingViewController;

// UIViewController has a private _popoverController ivar and property, but nothing named popoverController (yet?).
@property (strong, nonatomic) AwfulPopoverController *popoverController;

@end

@implementation AwfulSemiModalViewController
{
    BOOL _presenting;
    AwfulHoleyDimmingView *_dimmingView;
}

// _popoverController ivar collides with UIViewController.
@synthesize popoverController = _awful_popoverController;

- (void)presentFromView:(UIView *)view highlightingRegionReturnedByBlock:(AwfulSemiModalRectInViewBlock)regionBlock
{
    self.contextView = view;
    self.regionBlock = regionBlock;
    self.modalPresentationStyle = UIModalPresentationCustom;
    self.transitioningDelegate = self;
    
    self.directlyPresentingViewController = ViewControllerForView(view);
    if (!self.directlyPresentingViewController) {
        [NSException raise:NSInternalInconsistencyException format:@"Semi-modal view controllers must be presented from a view within a view controller"];
    }
    [self.directlyPresentingViewController presentViewController:self animated:YES completion:nil];
}

- (void)presentInPopoverFromBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    [self.popoverController presentPopoverFromBarButtonItem:barButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)presentInPopoverFromView:(UIView *)view pointingToRegionReturnedByBlock:(AwfulSemiModalRectInViewBlock)regionBlock
{
    self.contextView = view;
    self.regionBlock = regionBlock;
    [self.popoverController presentPopoverFromRect:[self contextRegion] inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (AwfulPopoverController *)popoverController
{
    if (_awful_popoverController) return _awful_popoverController;
    _awful_popoverController = [[AwfulPopoverController alloc] initWithContentViewController:self];
    _awful_popoverController.delegate = self;
    return _awful_popoverController;
}

- (void)setDirectlyPresentingViewController:(UIViewController *)directlyPresentingViewController
{
    _directlyPresentingViewController = directlyPresentingViewController;
    if ([self isViewLoaded]) {
        [self themeDidChange];
    }
}

- (BOOL)isShowingInPopover
{
    return _awful_popoverController.isPopoverVisible;
}

- (void)didTapDimmingView:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

static inline UIViewController * ViewControllerForView(UIView *view)
{
    id responder = view;
    while (responder) {
        responder = [responder nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            return responder;
        }
    }
    return nil;
}

- (void)dismissCompletion:(void (^)(void))completionBlock
{
    if ([self isShowingInPopover]) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
        if (completionBlock) {
            completionBlock();
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:completionBlock];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self positionViewAndPunchHole];
}

- (CGRect)contextRegion
{
    if (self.regionBlock) {
        return self.regionBlock(self.contextView);
    } else {
        return self.contextView.bounds;
    }
}

- (void)positionViewAndPunchHole
{
    UIView *presentingView = self.directlyPresentingViewController.view;
    _dimmingView.dimRect = [_dimmingView convertRect:presentingView.bounds fromView:presentingView];
    CGRect contextRegion = [self contextRegion];
    _dimmingView.hole = [_dimmingView convertRect:contextRegion fromView:self.contextView];
    
    // Calculate our frame relative to the contextView. Since our superview's transform is suspect, work with our view's bounds and judiciously use -convertRect:....
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(presentingView.bounds), 0);
    if ([[self.view class] requiresConstraintBasedLayout] || self.view.constraints.count > 0) {
        
        // If we use auto layout we must replicate how the auto layout system calculates a frame:
        //   1. Start with the intrinsic content size.
        //   2. Do a layout pass.
        //   3. Use the resulting intrinsic content size.
        CGFloat (^calculateHeight)(void) = ^{
            CGRect alignmentRect = (CGRect){ .size = self.view.intrinsicContentSize };
            CGRect frameForRect = [self.view frameForAlignmentRect:alignmentRect];
            return CGRectGetHeight(frameForRect);
        };
        frame.size.height = calculateHeight();
        self.view.bounds = frame;
        [self.view layoutIfNeeded];
        frame.size.height = calculateHeight();
    } else {
        self.view.bounds = frame;
        frame.size.height = self.preferredContentSize.height;
    }
    
    // If there's not enough room to show below the context region, show above it instead.
    frame.origin.y = CGRectGetMaxY(contextRegion);
    CGRect bounds = [self.contextView convertRect:presentingView.bounds fromView:presentingView];
    if (CGRectGetMaxY(frame) > CGRectGetMaxY(bounds)) {
        frame.origin.y = CGRectGetMinY(contextRegion) - CGRectGetHeight(frame);
    }
    
    // If there's still not enough room (our contextView has gone wildly off screen), just stay on the screen.
    if (CGRectGetMaxY(frame) > CGRectGetMaxY(bounds) || CGRectGetMinY(frame) < CGRectGetMinY(bounds)) {
        frame.origin.y = CGRectGetMaxY(bounds) - CGRectGetHeight(frame);
    }
    
    // Now convert our frame to our superview's coordinate system.
    self.view.frame = [self.view.superview convertRect:frame fromView:self.contextView];
}

- (CGSize)preferredContentSize
{
    // Subclasses must override.
    [self doesNotRecognizeSelector:_cmd];
    return CGSizeMake(0, 0);
}

- (AwfulTheme *)theme
{
    if ([self.directlyPresentingViewController respondsToSelector:@selector(theme)]) {
        return ((AwfulViewController *)self.directlyPresentingViewController).theme;
    } else {
        return [super theme];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    _dimmingView.backgroundColor = self.theme[@"sheetDimColor"];
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                   presentingController:(UIViewController *)presenting
                                                                       sourceController:(UIViewController *)source
{
    _presenting = YES;
    return self;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    _presenting = NO;
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.2;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    // Note that fromViewController (when presenting) or toViewController (when dismissing) may not be equal to _presentingViewController. This always seems true on iPhone, as technically we get presented by window's rootViewController.
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if (_presenting) {
        UIView *containerView = [transitionContext containerView];
        [containerView addSubview:toViewController.view];
        
        // Blanketing the presenting view controller with a dimming view also traps any interaction.
        _dimmingView = [[AwfulHoleyDimmingView alloc] initWithFrame:fromViewController.view.bounds];
        _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapDimmingView:)];
        [_dimmingView addGestureRecognizer:tap];
        _dimmingView.backgroundColor = self.theme[@"sheetDimColor"];
        [fromViewController.view addSubview:_dimmingView];
        
        [self positionViewAndPunchHole];
        
        _dimmingView.alpha = 0;
        toViewController.view.alpha = 0;
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            _dimmingView.alpha = 1;
            toViewController.view.alpha = 1;
            fromViewController.view.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    } else {
        UIView *containerView = [transitionContext containerView];
        [containerView insertSubview:toViewController.view belowSubview:fromViewController.view];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            _dimmingView.alpha = 0;
            fromViewController.view.alpha = 0;
            toViewController.view.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
        } completion:^(BOOL finished) {
            [_dimmingView removeFromSuperview];
            _dimmingView = nil;
            self.regionBlock = nil;
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    *rect = [self contextRegion];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popoverController = nil;
}

@end
