//  AwfulPopoverController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPopoverController.h"
#import "AwfulScreenCoverView.h"

// Draws a popover on behalf of an AwfulPopoverController.
@interface AwfulPopoverView : UIView

// Designated initializer.
- (id)initWithContentSize:(CGSize)contentSize;

@end


@interface AwfulPopoverController ()

@property (nonatomic) UIViewController *contentViewController;
@property (nonatomic) AwfulScreenCoverView *coverView;
@property (nonatomic) AwfulPopoverView *popoverView;

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
    if (!self.popoverView) {
        CGSize contentSize = self.contentViewController.preferredContentSize;
        self.popoverView = [[AwfulPopoverView alloc] initWithContentSize:contentSize];
        [self.popoverView addSubview:self.contentViewController.view];
    }
    if (!self.coverView) {
        self.coverView = [[AwfulScreenCoverView alloc] initWithWindow:view.window];
        [self.coverView setTarget:self action:@selector(didTapCoverView)];
        self.coverView.passthroughViews = @[ self.popoverView ];
    }
    
    CGRect popoverFrame = self.popoverView.frame;
    popoverFrame.origin.x = CGRectGetMidX(rect) - (CGRectGetWidth(popoverFrame) / 2);
    popoverFrame.origin.y = CGRectGetMinY(rect) - CGRectGetHeight(popoverFrame);
    self.popoverView.frame = popoverFrame;
    
    if (!self.popoverView.superview) {
        [self.contentViewController viewWillAppear:animated];
        [view addSubview:self.popoverView];
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
    [self.popoverView removeFromSuperview];
    [self.coverView removeFromSuperview];
    self.coverView = nil;
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
