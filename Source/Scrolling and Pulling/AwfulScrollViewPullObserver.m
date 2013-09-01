//  AwfulScrollViewPullObserver.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrollViewPullObserver.h"

@implementation AwfulScrollViewPullObserver
{
    BOOL _wasDragging;
    BOOL _wouldHaveTriggered;
    BOOL _triggered;
}

- (id)initWithScrollView:(UIScrollView *)scrollView
               direction:(AwfulScrollViewPullDirection)direction
           triggerOffset:(CGFloat)triggerOffset
{
    if (!(self = [super init])) return nil;
    _scrollView = scrollView;
    _direction = direction;
    _triggerOffset = triggerOffset;
    [_scrollView addObserver:self
                  forKeyPath:@"contentOffset"
                     options:NSKeyValueObservingOptionOld
                     context:&KVOContext];
    return self;
}

- (void)reset
{
    _wouldHaveTriggered = NO;
    _wasDragging = NO;
    _triggered = NO;
}

- (void)willLeaveScrollView:(UIScrollView *)scrollView
{
    [scrollView removeObserver:self forKeyPath:@"contentOffset" context:&KVOContext];
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &KVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if (_triggered) return;
    
    CGFloat currentOffset = [change[NSKeyValueChangeOldKey] CGPointValue].y;
    BOOL wouldTrigger = NO;
    if (self.direction == AwfulScrollViewPullDown) {
        wouldTrigger = currentOffset <= -self.triggerOffset;
    } else if (self.direction == AwfulScrollViewPullUp) {
        CGFloat contentHeight = self.scrollView.contentSize.height;
        CGFloat visibleHeight = self.scrollView.frame.size.height;
        CGFloat relevantHeight = visibleHeight > contentHeight ? visibleHeight : contentHeight;
        CGFloat exposedBottom = currentOffset + self.scrollView.frame.size.height - relevantHeight;
        wouldTrigger = exposedBottom >= self.triggerOffset;
    }
    
    if (wouldTrigger && _wasDragging && !self.scrollView.dragging) {
        BOOL wasntTriggered = !_triggered;
        _triggered = YES;
        if (wasntTriggered && self.didTrigger) self.didTrigger();
    } else if (self.scrollView.dragging) {
        if (wouldTrigger) {
            if (!_wouldHaveTriggered && self.willTrigger) self.willTrigger();
        } else {
            if (_wouldHaveTriggered && self.willNotTrigger) self.willNotTrigger();
        }
    }
    _wouldHaveTriggered = wouldTrigger;
    _wasDragging = self.scrollView.dragging;
}

static void * KVOContext = @"AwfulPullToRefreshObserver KVO";

#pragma mark - NSObject

- (id)init
{
    return [self initWithScrollView:nil direction:0 triggerOffset:0];
}

@end
