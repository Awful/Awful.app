//  AwfulPostsView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsView.h"
#import "AwfulFrameworkCategories.h"
#import "Awful-Swift.h"

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
@property (assign, nonatomic) BOOL topBarAlwaysVisible;

@end

@implementation AwfulPostsView

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _webView = [UIWebView awful_nativeFeelingWebView];
        _webView.backgroundColor = nil;
        [self addSubview:_webView];
        _webView.scrollView.delegate = self;
        
        _topBar = [PostsViewTopBar new];
        [self addSubview:_topBar];
        
        self.maintainTopBarState = YES;
        
        [self updateForVoiceOverAnimated:NO];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voiceOverStatusDidChange:) name:UIAccessibilityVoiceOverStatusChanged object:nil];
    }
    return self;
}

- (void)layoutSubviews
{
    CGFloat fractionalOffset = self.webView.awful_fractionalContentOffset;
    
    CGRect topBarFrame = self.topBar.bounds;
    topBarFrame.origin.y = self.exposedTopBarSlice - CGRectGetHeight(topBarFrame);
    topBarFrame.size.width = CGRectGetWidth(self.bounds);
    self.topBar.frame = topBarFrame;
    
    /*
     This silliness combats an annoying interplay on iOS 8 between UISplitViewController and UIWebView. On a 2x Retina iPad in landscape with the sidebar always visible, the width is distributed like so:
     
                 separator(0.5)
     |--sidebar(350)--|------------posts(673.5)------------|
     
     Unfortunately, UIWebView doesn't particularly like a fractional portion to its width, and it will round up its content size to 674 in this example. And now that the content is wider than the viewport, we get horizontal scrolling.
     
     (And if you ask UISplitViewController to set a maximumPrimaryColumnWidth of, say, 349.5 to take the separator into account, it will simply round down to 349.)
     */
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat integral = floor(width);
    CGFloat fractional = width - integral;
    self.webView.frame = CGRectMake(fractional, CGRectGetMaxY(topBarFrame), integral, CGRectGetHeight(self.bounds) - self.exposedTopBarSlice);
    
    // When the app enters the background, on iPad, the width of the view changes dramatically while the system takes a snapshot. The end result is that when you leave Awful then come back, you're scrolled away from where you actually were when you left. Here we try to combat that.
    // That said, if we're in the middle of dragging, messing with contentOffset just makes scrolling janky.
    if (!self.webView.scrollView.dragging) {
        self.webView.awful_fractionalContentOffset = fractionalOffset;
    }
}

- (void)updateForVoiceOverAnimated:(BOOL)animated
{
    self.topBarAlwaysVisible = UIAccessibilityIsVoiceOverRunning();
    if (self.topBarAlwaysVisible) {
        self.exposedTopBarSlice = CGRectGetHeight(self.topBar.bounds);
        [UIView animateWithDuration:(animated ? 0.2 : 0) animations:^{
            [self layoutIfNeeded];
        }];
    }
}

- (void)voiceOverStatusDidChange:(NSNotification *)notification
{
    [self updateForVoiceOverAnimated:YES];
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
    if (self.ignoreScrollViewDidScroll || self.topBarAlwaysVisible) return;
    
    CGFloat scrollDistance = scrollView.contentOffset.y - self.lastContentOffset.y;
    if (scrollDistance == 0) return;
    
    switch (self.topBarState) {
        case TopBarHidden: {
            
            // Don't start showing a hidden topbar after bouncing.
            if (self.maintainTopBarState) break;
            
            // Only moving the content down can expose the topbar.
            if (scrollDistance < 0) {
                
                // Only start showing the topbar if we're scrolling past the bottom of the scrollview's contents. Otherwise we can briefly trap ourselves at the bottom, exposing some topbar causing the scrollview to bounce back.
                if (CGRectGetMaxY(scrollView.bounds) - scrollView.contentInset.bottom - scrollDistance <= scrollView.contentSize.height) {
                    [self furtherExposeTopBarSlice:-scrollDistance];
                }
            }
            break;
        }
            
        case TopBarPartiallyVisible: {
            [self furtherExposeTopBarSlice:-scrollDistance];
            break;
        }
            
        case TopBarVisible: {
            
            // Don't start hiding a visible topbar after bouncing.
            if (self.maintainTopBarState) break;
            
            // Only start hiding the topbar if we're scrolling past the top of the scrollview's contents. Otherwise we can briefly trap ourselves at the top, hiding some topbar causing the scrollview to bounce back.
            if (scrollView.contentOffset.y < 0) break;
            
            // Only moving the content up can hide the topbar.
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
