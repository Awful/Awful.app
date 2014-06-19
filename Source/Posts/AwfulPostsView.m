//  AwfulPostsView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsView.h"
#import "AwfulFrameworkCategories.h"

typedef enum : NSInteger {
    TopBarHidden,
    TopBarPartiallyVisible,
    TopBarVisible,
} TopBarState;

@interface AwfulPostsView () <UIScrollViewDelegate>

@property (strong, nonatomic) UIWebView *webView;

@property (assign, nonatomic) CGFloat exposedTopBarSlice;
@property (assign, nonatomic) CGPoint lastContentOffset;
@property (readonly, assign, nonatomic) TopBarState topBarState;
@property (assign, nonatomic) BOOL ignoreScrollViewDidScroll;
@property (assign, nonatomic) BOOL maintainTopBarState;

@end

@implementation AwfulPostsView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _webView = [UIWebView awful_nativeFeelingWebView];
        _webView.backgroundColor = nil;
        [self addSubview:_webView];
        _webView.scrollView.delegate = self;
        
        _topBar = [AwfulPostsViewTopBar new];
        [self addSubview:_topBar];
    }
    return self;
}

- (void)layoutSubviews
{
    CGRect topBarFrame = self.topBar.bounds;
    topBarFrame.origin.y = self.exposedTopBarSlice - CGRectGetHeight(topBarFrame);
    topBarFrame.size.width = CGRectGetWidth(self.bounds);
    self.topBar.frame = topBarFrame;
    
    self.webView.frame = CGRectMake(0, CGRectGetMaxY(topBarFrame), CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - self.exposedTopBarSlice);
}

- (void)furtherExposeTopBarSlice:(CGFloat)delta
{
    CGFloat oldExposedSlice = self.exposedTopBarSlice;
    #define CLAMP(low, x, high) MIN(MAX(low, x), high)
    self.exposedTopBarSlice = CLAMP(0, self.exposedTopBarSlice + delta, CGRectGetHeight(self.topBar.bounds));
    CGFloat exposedSliceDelta = self.exposedTopBarSlice - oldExposedSlice;
    
    self.ignoreScrollViewDidScroll = YES;
    CGPoint contentOffset = self.webView.scrollView.contentOffset;
    contentOffset.y = MAX(contentOffset.y + exposedSliceDelta, 0);
    self.webView.scrollView.contentOffset = contentOffset;
    self.ignoreScrollViewDidScroll = NO;
}

- (TopBarState)topBarState
{
    if (self.exposedTopBarSlice == 0) {
        return TopBarHidden;
    } else if (self.exposedTopBarSlice >= CGRectGetHeight(self.topBar.bounds)) {
        return TopBarVisible;
    } else {
        return TopBarPartiallyVisible;
    }
}

- (void)setExposedTopBarSlice:(CGFloat)exposedTopBarSlice
{
    if (exposedTopBarSlice != _exposedTopBarSlice) {
        _exposedTopBarSlice = exposedTopBarSlice;
        [self setNeedsLayout];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.lastContentOffset = scrollView.contentOffset;
    self.maintainTopBarState = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.ignoreScrollViewDidScroll) return;
    
    CGFloat scrollDistance = scrollView.contentOffset.y - self.lastContentOffset.y;
    if (scrollDistance == 0) return;
    
    switch (self.topBarState) {
        case TopBarHidden: {
            if (scrollDistance < 0 && !self.maintainTopBarState) {
                [self furtherExposeTopBarSlice:-scrollDistance];
            }
            break;
        }
            
        case TopBarPartiallyVisible: {
            [self furtherExposeTopBarSlice:-scrollDistance];
            break;
        }
            
        case TopBarVisible: {
            if (self.maintainTopBarState) break;
            if (scrollView.contentOffset.y < 0) break;
            if (scrollDistance > 0) {
                [self furtherExposeTopBarSlice:-scrollDistance];
            }
            break;
        }
    }
    
    self.lastContentOffset = scrollView.contentOffset;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
    self.maintainTopBarState = YES;
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    self.maintainTopBarState = YES;
    return YES;
}

@end
