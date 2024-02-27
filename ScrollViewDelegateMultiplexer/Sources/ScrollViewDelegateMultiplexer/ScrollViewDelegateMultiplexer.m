//  ScrollViewDelegateMultiplexer.m
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ScrollViewDelegateMultiplexer.h"

NS_ASSUME_NONNULL_BEGIN

// This is written in Objective-C so that we can use `-forwardInvocation`.

@implementation ScrollViewDelegateMultiplexer {
    NSPointerArray *_delegates;
    
    // We can't use `__weak` here or it'll be set to `nil` by the time our `-dealloc` runs, and we need to remove ourselves as a KVO observer to avoid an exception.
    UIScrollView *_scrollView;
}

- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    if ((self = [super init])) {
        _delegates = [NSPointerArray weakObjectsPointerArray];
        _scrollView = scrollView;
        
        _scrollView.delegate = self;
        
        [_scrollView addObserver:self
                      forKeyPath:@"contentSize"
                         options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
                         context:KVOContext];
    }
    return self;
}

- (void)dealloc {
    if (_scrollView.delegate == self) {
        _scrollView.delegate = nil;
    }
    [_scrollView removeObserver:self forKeyPath:@"contentSize" context:KVOContext];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context
{
    if (context != KVOContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    NSParameterAssert(object == _scrollView);
    NSParameterAssert([keyPath isEqualToString:@"contentSize"]);
    
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    if (!([oldValue isKindOfClass:[NSValue class]] && [newValue isKindOfClass:[NSValue class]])) {
        return;
    }
    
    if ([oldValue isEqual:newValue]) {
        return;
    }
    
    UIScrollView *scrollView = object;
    if (!scrollView) {
        return;
    }
    
    for (id<ScrollViewDelegateExtras> delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(awful_scrollViewDidChangeContentSize:)]) {
            [delegate awful_scrollViewDidChangeContentSize:scrollView];
        }
    }
}

static void *KVOContext = &KVOContext;

#pragma mark Multiplexing

- (void)addDelegate:(id<UIScrollViewDelegate>)delegate {
    [_delegates addPointer:(__bridge void *)delegate];
    
    // UIScrollView (and subclasses) sometimes cache `-respondsToSelector:` queries, so we should reset that now that things may have changed.
    if (_scrollView.delegate == self){
        _scrollView.delegate = nil;
        _scrollView.delegate = self;
    }
}

- (void)removeDelegate:(id<UIScrollViewDelegate>)delegate {
    for (NSUInteger i = 0, end = _delegates.count; i < end; i++) {
        if ([_delegates pointerAtIndex:i] == (__bridge void *)delegate) {
            [_delegates replacePointerAtIndex:i withPointer:nil];
        }
    }
    
    // NSPointerArray refuses to compact unless `nil` was added since the last call to `-compact`.
    [_delegates addPointer:nil];
    
    [_delegates compact];
    
    // The scroll view's `-respondsToSelector:` query cache is also relevant here. (See `-addDelegate:` for more info.)
    if (_scrollView.delegate == self){
        _scrollView.delegate = nil;
        _scrollView.delegate = self;
    }
}

- (BOOL)respondsToSelector:(SEL)selector {
    if ([super respondsToSelector:selector]) {
        return YES;
    }
    for (id<UIScrollViewDelegate> delegate in _delegates) {
        if ([delegate respondsToSelector:selector]) {
            return YES;
        }
    }
    return NO;
}

- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (!signature) {
        for (NSObject *delegate in _delegates) {
            signature = [delegate methodSignatureForSelector:selector];
            if (signature) { break; }
        }
    }
    return signature;
}

- (nullable id)forwardingTargetForSelector:(SEL)selector {
    if (_delegates.count == 1) {
        id<UIScrollViewDelegate> potentialTarget = [_delegates pointerAtIndex:0];
        if ([potentialTarget respondsToSelector:selector]) {
            return potentialTarget;
        }
    }
    return nil;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    for (id<UIScrollViewDelegate> delegate in _delegates) {
        if ([delegate respondsToSelector:invocation.selector]) {
            [invocation invokeWithTarget:delegate];
        }
    }
}

@end

NS_ASSUME_NONNULL_END
