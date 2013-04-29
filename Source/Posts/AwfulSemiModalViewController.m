//
//  AwfulSemiModalViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulSemiModalViewController.h"

@interface AwfulSemiModalViewController () <UIPopoverControllerDelegate>

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) UIView *coverView;
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
        [self slideUpFromBottomOverViewController:viewController];
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
{
    UIView *backView = viewController.view;
    self.coverView.frame = (CGRect){ .size = backView.bounds.size };
    self.coverView.alpha = 0;
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(didTapCoverView:)];
    [self.coverView addGestureRecognizer:tap];
    // (Ab)use the view controller container to keep us around, and so we rotate.
    [viewController addChildViewController:self];
    self.view.frame = (CGRect){
        .origin.y = CGRectGetMaxY(backView.bounds),
        .size.width = CGRectGetWidth(backView.bounds),
        .size.height = CGRectGetHeight(self.view.frame),
    };
    [backView addSubview:self.coverView];
    [backView addSubview:self.view];
    [self didMoveToParentViewController:viewController];
    [UIView animateWithDuration:0.3 animations:^{
        self.coverView.alpha = 0.5;
        self.view.frame = CGRectOffset(self.view.frame, 0, -CGRectGetHeight(self.view.frame));
    }];
}

- (UIView *)coverView
{
    if (!_coverView) {
        _coverView = [UIView new];
        _coverView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight);
        _coverView.backgroundColor = [UIColor blackColor];
    }
    return _coverView;
}

- (void)didTapCoverView:(UITapGestureRecognizer *)tap
{
    if (tap.state == UIGestureRecognizerStateEnded) {
        [self userDismiss];
    }
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
