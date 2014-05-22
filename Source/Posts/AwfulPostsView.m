//  AwfulPostsView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsView.h"

@interface AwfulPostsView ()

@property (strong, nonatomic) UIWebView *webView;

@end

@implementation AwfulPostsView
{
    BOOL _ignoreObservedContentOffsetChange;
}

- (void)dealloc
{
    [self.webView.scrollView removeObserver:self forKeyPath:@"contentSize" context:KVOContentSizeContext];
    [self.webView.scrollView removeObserver:self forKeyPath:@"contentOffset" context:KVOContentOffsetContext];
}

- (id)initWithWebView:(UIWebView *)webView
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _webView = webView;
        [self addSubview:webView];
        UIScrollView *scrollView = webView.scrollView;
        scrollView.scrollEnabled = NO;
        scrollView.showsVerticalScrollIndicator = NO;
        [scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionOld context:KVOContentSizeContext];
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionOld context:KVOContentOffsetContext];
    }
    return self;
}

static void * KVOContentSizeContext = &KVOContentSizeContext;
static void * KVOContentOffsetContext = &KVOContentOffsetContext;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContentSizeContext) {
        UIScrollView *scrollView = object;
        CGSize oldContentSize = [change[NSKeyValueChangeOldKey] CGSizeValue];
        if (!CGSizeEqualToSize(scrollView.contentSize, oldContentSize)) {
            [self setNeedsLayout];
        }
    } else if (context == KVOContentOffsetContext) {
        if (!_ignoreObservedContentOffsetChange) {
            UIScrollView *scrollView = object;
            CGPoint oldOffset = [change[NSKeyValueChangeOldKey] CGPointValue];
            if (!CGPointEqualToPoint(oldOffset, scrollView.contentOffset)) {
                self.contentOffset = scrollView.contentOffset;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect frame = self.webView.frame;
    UIScrollView *scrollView = self.webView.scrollView;
    CGPoint contentOffset = scrollView.contentOffset;
    
    // Scrolled up past the top of the web view. Pin it to the top left.
    if (self.contentOffset.y < 0) {
        contentOffset.y = 0;
        frame.origin.y = 0;
    }
    
    // Scrolled down enough to scroll the web view.
    else {
        contentOffset.y = self.contentOffset.y;
        frame.origin.y = self.contentOffset.y;
    }
    
    frame.size = self.bounds.size;
    self.webView.frame = frame;
    
    // Avoid infinite recursion.
    _ignoreObservedContentOffsetChange = YES;
    scrollView.contentOffset = contentOffset;
    _ignoreObservedContentOffsetChange = NO;
    
    self.contentSize = scrollView.contentSize;
}

@end
