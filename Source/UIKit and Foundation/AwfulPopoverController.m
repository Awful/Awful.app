//
//  AwfulPopoverController.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-06.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPopoverController.h"

// Draws a popover on behalf of an AwfulPopoverController.
@interface AwfulPopoverView : UIView

// Designated initializer.
- (id)initWithContentSize:(CGSize)contentSize;

@end


@interface AwfulPopoverController ()

@property (nonatomic) UIViewController *contentViewController;
@property (weak, nonatomic) AwfulPopoverView *popoverView;
@property (weak, nonatomic) UIView *coverView;

@end


@implementation AwfulPopoverController

- (id)initWithContentViewController:(UIViewController *)contentViewController
{
    if (!(self = [super init])) return nil;
    self.contentViewController = contentViewController;
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)presentPopoverFromRect:(CGRect)rect
                        inView:(UIView *)view
                      animated:(BOOL)animated
{
    UIView *windowContentView = self.coverView.superview ?: [view.window.subviews lastObject];
    
    if (!self.coverView) {
        CGSize contentSize = self.contentViewController.contentSizeForViewInPopover;
        AwfulPopoverView *popover = [[AwfulPopoverView alloc] initWithContentSize:contentSize];
        self.popoverView = popover;
        [self.popoverView addSubview:self.contentViewController.view];
        UIView *coverView = [[UIView alloc] initWithFrame:windowContentView.bounds];
        self.coverView = coverView;
        self.coverView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                           UIViewAutoresizingFlexibleHeight);
        UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
        [tap addTarget:self action:@selector(didTapCoverView)];
        [self.coverView addGestureRecognizer:tap];
    }
    
    CGRect rectInCoverView = [windowContentView convertRect:rect fromView:view];
    CGRect popoverFrame = self.popoverView.frame;
    popoverFrame.origin.x = CGRectGetMidX(rectInCoverView) - (CGRectGetWidth(popoverFrame) / 2);
    popoverFrame.origin.y = CGRectGetMinY(rectInCoverView) - CGRectGetHeight(popoverFrame);
    self.popoverView.frame = popoverFrame;
    
    if (!self.coverView.superview) {
        [self.contentViewController viewWillAppear:animated];
        [self.coverView addSubview:self.popoverView];
        [windowContentView addSubview:self.coverView];
        [self.contentViewController viewDidAppear:animated];
    }
}

- (void)didTapCoverView
{
    [self dismissPopoverAnimated:NO];
    [self.delegate popoverControllerDidDismissPopover:self];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
    [self.contentViewController viewWillDisappear:animated];
    [self.coverView removeFromSuperview];
    [self.contentViewController viewDidDisappear:animated];
}

@end


@interface AwfulPopoverView ()

@property (nonatomic) CGSize contentSize;

@end


@implementation AwfulPopoverView

- (id)initWithContentSize:(CGSize)contentSize
{
    CGRect frame = (CGRect){ .size = contentSize };
    frame.size.width += 2 * BorderWidth;
    frame.size.height += 2 * BorderWidth + ArrowHeight;
    if (!(self = [super initWithFrame:frame])) return nil;
    self.contentSize = contentSize;
    self.backgroundColor = [UIColor clearColor];
    return self;
}

const CGFloat BorderWidth = 8;
const CGFloat ArrowHeight = 18;

#pragma mark - UIView

- (void)didAddSubview:(UIView *)subview
{
    subview.layer.cornerRadius = 4;
    subview.layer.masksToBounds = YES;
}

- (void)layoutSubviews
{
    UIView *content = [self.subviews lastObject];
    content.frame = CGRectMake(BorderWidth, BorderWidth,
                               self.contentSize.width, self.contentSize.height);
}

- (void)drawRect:(CGRect)rect
{
    [[UIBezierPath bezierPathWithRect:rect] addClip];
    [[UIColor blackColor] set];
    
    CGRect border = self.bounds;
    border.size.height -= ArrowHeight;
    [[UIBezierPath bezierPathWithRoundedRect:border cornerRadius:8] fill];
    
    UIBezierPath *arrow = [UIBezierPath bezierPath];
    CGPoint arrowPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMaxY(self.bounds));
    [arrow moveToPoint:arrowPoint];
    const CGFloat arrowWidth = 34;
    [arrow addLineToPoint:CGPointMake(arrowPoint.x - arrowWidth / 2, arrowPoint.y - ArrowHeight)];
    [arrow addLineToPoint:CGPointMake(arrowPoint.x + arrowWidth / 2, arrowPoint.y - ArrowHeight)];
    [arrow fill];
}

@end
