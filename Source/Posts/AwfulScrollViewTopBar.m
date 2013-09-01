//  AwfulScrollViewTopBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrollViewTopBar.h"

@interface AwfulScrollViewTopBar ()

@property (weak, nonatomic) UIScrollView *scrollView;

@property (nonatomic) CGPoint lastContentOffset;

@property (nonatomic) BOOL scrollingUp;

@end


@implementation AwfulScrollViewTopBar

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if ([newSuperview isKindOfClass:[UIScrollView class]]) {
        self.scrollView = (id)newSuperview;
        CGRect frame = self.frame;
        frame.origin.x = 0;
        frame.origin.y = -CGRectGetHeight(self.frame);
        self.frame = frame;
        [self setNeedsLayout];
        IncreaseScrollViewTopOffset(self.scrollView, CGRectGetHeight(self.frame));
    } else {
        IncreaseScrollViewTopOffset(self.scrollView, -CGRectGetHeight(self.frame));
        self.scrollView = nil;
    }
}

static void IncreaseScrollViewTopOffset(UIScrollView *scrollView, CGFloat offset)
{
    UIEdgeInsets contentInset = scrollView.contentInset;
    contentInset.top += offset;
    scrollView.contentInset = contentInset;
    UIEdgeInsets scrollIndicatorInsets = scrollView.scrollIndicatorInsets;
    scrollIndicatorInsets.top += offset;
    scrollView.scrollIndicatorInsets = scrollIndicatorInsets;
}

#pragma mark - UIScrollViewDelegate (forwarded)

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.lastContentOffset = scrollView.contentOffset;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGRect frame = self.frame;
    if (scrollView.contentOffset.y <= -CGRectGetHeight(frame)) {
        // Don't slide or bounce under the navigation bar.
        frame.origin.y = scrollView.contentOffset.y;
    } else {
        if (!self.scrollingUp) {
            // When scrolling down, scroll along with the content...
            if (!CGRectIntersectsRect(frame, scrollView.bounds)) {
                // ...until we're out of sight, then perch atop the scroll view.
                frame.origin.y = -CGRectGetHeight(frame);
            }
        } else if (CGRectGetMinY(frame) > scrollView.contentOffset.y) {
            // When scrolling up, if we were visible, stay visible.
            frame.origin.y = CGRectGetMinY(scrollView.bounds);
        }
    }
    self.frame = frame;
    if (CGPointEqualToPoint(self.lastContentOffset, scrollView.contentOffset)) return;
    self.scrollingUp = scrollView.contentOffset.y < self.lastContentOffset.y;
    self.lastContentOffset = scrollView.contentOffset;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    // Now may be the time to let go of our perch atop the scroll view.
    // But only if we're decelerating upwards.
    if (!decelerate || !self.scrollingUp) return;
    
    CGRect frame = self.frame;
    
    // And only if we're not stuck under the navigation bar.
    if (CGRectGetMinY(frame) < -CGRectGetHeight(frame)) return;
    
    // And only if we're not already visible.
    if (CGRectGetMinY(frame) >= CGRectGetMinY(scrollView.bounds) - CGRectGetHeight(frame)) return;
    
    frame.origin.y = CGRectGetMinY(scrollView.bounds) - CGRectGetHeight(frame);
    if (CGRectGetMinY(frame) < -CGRectGetHeight(frame)) {
        frame.origin.y = -CGRectGetHeight(frame);
    }
    self.frame = frame;
}

@end
