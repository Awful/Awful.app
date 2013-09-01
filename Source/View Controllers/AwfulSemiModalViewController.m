//  AwfulSemiModalViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
#import "AwfulScreenCoverView.h"

@interface AwfulSemiModalViewController () <UIPopoverControllerDelegate>

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) AwfulScreenCoverView *coverView;
@property (weak, nonatomic) UIView *viewPresentingPopover;
@property (nonatomic) CGRect rectInViewPresentingPopover;

@end


@implementation AwfulSemiModalViewController

- (void)presentFromViewController:(UIViewController *)viewController
                         fromRect:(CGRect)rect
                           inView:(UIView *)view
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self presentInPopoverFromRect:rect inView:view];
    } else {
        [self slideUpFromBottomOverViewController:viewController atopRect:rect inView:view];
    }
}

- (void)presentInPopoverFromRect:(CGRect)rect inView:(UIView *)view
{
    if (!self.popover) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:self];
        self.popover.delegate = self;
        self.popover.popoverContentSize = self.view.frame.size;
    }
    self.viewPresentingPopover = view;
    self.rectInViewPresentingPopover = rect;
    if (CGRectEqualToRect(rect, CGRectZero)) {
        rect = view.bounds;
    }
    [self.popover presentPopoverFromRect:rect inView:view
                permittedArrowDirections:UIPopoverArrowDirectionAny
                                animated:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)deviceOrientationDidChange:(NSNotification *)note
{
    CGRect rect = self.rectInViewPresentingPopover;
    if (self.viewPresentingPopover.window && CGRectEqualToRect(rect, CGRectZero)) {
        [self.popover presentPopoverFromRect:self.viewPresentingPopover.bounds
                                      inView:self.viewPresentingPopover
                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                    animated:NO];
    } else {
        [self dismiss];
    }
}

- (void)slideUpFromBottomOverViewController:(UIViewController *)viewController
                                   atopRect:(CGRect)rect
                                     inView:(UIView *)view
{
    self.coverView = [[AwfulScreenCoverView alloc] initWithWindow:view.window];
    self.coverView.passthroughViews = @[ self.view ];
    [self.coverView setTarget:self action:@selector(didTapCoverView)];
    UIView *backView = view.superview;
    // (Ab)use the view controller container to keep us around, and so we rotate.
    [viewController addChildViewController:self];
    CGRect localBackViewRect = [backView convertRect:rect fromView:view];
    self.view.frame = (CGRect){
        .origin.y = CGRectGetMinY(localBackViewRect),
        .size.width = CGRectGetWidth(backView.bounds),
        .size.height = CGRectGetHeight(self.view.frame),
    };
    self.view.accessibilityViewIsModal = YES;
    [backView insertSubview:self.view belowSubview:view];
    [self didMoveToParentViewController:viewController];
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = CGRectOffset(self.view.frame, 0, -CGRectGetHeight(self.view.frame));
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.view);
    }];
}

- (void)didTapCoverView
{
    [self userDismiss];
}

- (void)userDismiss
{
    // noop
}

- (void)dismiss
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    if (self.coverView) {
        [UIView animateWithDuration:0.3 animations:^{
            self.coverView.alpha = 0;
            self.view.frame = CGRectOffset(self.view.frame, 0, CGRectGetHeight(self.view.frame));
        } completion:^(BOOL finished) {
            [self willMoveToParentViewController:nil];
            [self.view removeFromSuperview];
            [self.coverView removeFromSuperview];
            self.coverView = nil;
            [self removeFromParentViewController];
        }];
    }
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    [self userDismiss];
    return NO;
}

@end
