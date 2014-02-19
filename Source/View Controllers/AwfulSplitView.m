//  AwfulSplitView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSplitView.h"

@interface AwfulSplitView ()

@property (strong, nonatomic) UIView *detailCoverView;

@end

@implementation AwfulSplitView
{
    BOOL _masterViewHidden;
    UIView *_masterContainerView;
    UIView *_detailContainerView;
    UIView *_detailCoverView;
    NSArray *_detailCoverConstraints;
    NSArray *_stuckVisibleConstraints;
    NSLayoutConstraint *_masterViewHiddenConstraint;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _masterContainerView = [UIView new];
    _masterContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _masterContainerView.clipsToBounds = YES;
    _masterContainerView.backgroundColor = [UIColor blackColor];
    [self addSubview:_masterContainerView];
    
    _detailContainerView = [UIView new];
    _detailContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _detailContainerView.clipsToBounds = YES;
    _detailContainerView.backgroundColor = [UIColor blackColor];
    [self insertSubview:_detailContainerView belowSubview:_masterContainerView];
    
    UISwipeGestureRecognizer *swipeGestureRecognizer = [UISwipeGestureRecognizer new];
    [swipeGestureRecognizer addTarget:self action:@selector(didSwipeToShowMasterView:)];
    [_detailContainerView addGestureRecognizer:swipeGestureRecognizer];
    
    NSDictionary *views = @{ @"master": _masterContainerView,
                             @"detail": _detailContainerView };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0@750-[master(383)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    _stuckVisibleConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[master][detail]|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:views];
    _masterViewHiddenConstraint = [NSLayoutConstraint constraintWithItem:_masterContainerView
                                                               attribute:NSLayoutAttributeRight
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self
                                                               attribute:NSLayoutAttributeLeft
                                                              multiplier:1
                                                                constant:0];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[master]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0@750-[detail]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[detail]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    return self;
}

- (void)setMasterView:(UIView *)masterView
{
    [_masterView removeFromSuperview];
    _masterView = masterView;
    masterView.translatesAutoresizingMaskIntoConstraints = NO;
    [_masterContainerView addSubview:masterView];
    
    NSDictionary *views = @{ @"master": masterView };
    [_masterContainerView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[master]-1-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_masterContainerView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[master]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
}

- (void)setDetailView:(UIView *)detailView
{
    [self setDetailView:detailView animated:NO];
}

- (void)setDetailView:(UIView *)detailView animated:(BOOL)animated
{
    if (animated) {
        UIView *snapshot = [_detailContainerView snapshotViewAfterScreenUpdates:NO];
        snapshot.frame = _detailContainerView.frame;
        [self insertSubview:snapshot aboveSubview:_detailContainerView];
        [UIView animateWithDuration:0.2 animations:^{
            snapshot.alpha = 0;
        } completion:^(BOOL finished) {
            [snapshot removeFromSuperview];
        }];
    }
    
    [_detailView removeFromSuperview];
    _detailView = detailView;
    _detailView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _detailView.frame = (CGRect){ .size = _detailContainerView.bounds.size };
    [_detailContainerView addSubview:detailView];
    
    // Immediately lay out new datail view so it doesn't animate into position.
    [_detailContainerView layoutIfNeeded];
}

- (BOOL)masterViewHidden
{
    return self.masterViewStuckVisible ? NO : _masterViewHidden;
}

- (void)setMasterViewHidden:(BOOL)masterViewHidden
{
    if (self.masterViewStuckVisible) return;
    _masterViewHidden = masterViewHidden;
    [self removeConstraint:_masterViewHiddenConstraint];
    [self updateCoverView];
    [self setNeedsUpdateConstraints];
}

- (void)setMasterViewStuckVisible:(BOOL)masterViewStuckVisible
{
    _masterViewStuckVisible = masterViewStuckVisible;
    [self removeConstraints:_stuckVisibleConstraints];
    [self removeConstraint:_masterViewHiddenConstraint];
    [self updateCoverView];
    [self setNeedsUpdateConstraints];
}

- (UIView *)detailCoverView
{
    if (_detailCoverView) return _detailCoverView;
    _detailCoverView = [UIView new];
    _detailCoverView.translatesAutoresizingMaskIntoConstraints = NO;
    _detailCoverView.backgroundColor = [UIColor clearColor];
    _detailCoverView.isAccessibilityElement = YES;
    _detailCoverView.accessibilityHint = @"Double tap to dismiss sidebar";
    
    UITapGestureRecognizer *tapGestureRecognizer = [UITapGestureRecognizer new];
    [tapGestureRecognizer addTarget:self action:@selector(didTapToHideDetailView:)];
    [_detailCoverView addGestureRecognizer:tapGestureRecognizer];
    
    UISwipeGestureRecognizer *swipeLeftGestureRecognizer = [UISwipeGestureRecognizer new];
    [swipeLeftGestureRecognizer addTarget:self action:@selector(didSwipeToPopNavigationController:)];
    [_detailCoverView addGestureRecognizer:swipeLeftGestureRecognizer];
    return _detailCoverView;
}

- (void)setDetailCoverView:(UIView *)detailCoverView
{
    [_detailCoverView removeFromSuperview];
    _detailCoverView = detailCoverView;
}

- (void)didTapToHideDetailView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.delegate splitViewDidTapDetailViewWhenMasterViewVisible:self];
    }
}

- (void)didSwipeToShowMasterView:(UISwipeGestureRecognizer *)sender
{
    if (self.masterViewHidden) {
        [self.delegate splitViewDidSwipeToShowMasterView:self];
    }
}

- (void)didSwipeToPopNavigationController:(UISwipeGestureRecognizer *)sender
{
    [self.delegate splitViewDidSwipeToPopNavigationController:self];
}

- (void)updateCoverView
{
    if (self.masterViewHidden) {
        self.detailCoverView = nil;
    } else {
        [_detailContainerView addSubview:self.detailCoverView];
        NSDictionary *views = @{ @"cover": _detailCoverView };
        [_detailContainerView addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[cover]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [_detailContainerView addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cover]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
}

- (void)updateConstraints
{
    if (self.masterViewStuckVisible) {
        [self addConstraints:_stuckVisibleConstraints];
    }
    if (self.masterViewHidden) {
        [self addConstraint:_masterViewHiddenConstraint];
    }
    [super updateConstraints];
}

@end
