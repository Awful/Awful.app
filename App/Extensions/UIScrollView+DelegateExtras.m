//  UIScrollView+DelegateExtras.m
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIScrollView+DelegateExtras.h"
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// This is written in Objective-C so that we can use `-forwardInvocation`.

@interface ScrollViewDelegateMultiplexer : NSObject <UIScrollViewDelegate>

@property (weak, nonatomic) UIScrollView *scrollView;

- (instancetype)initWithScrollView:(UIScrollView *)scrollView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)addDelegate:(id<UIScrollViewDelegate>)delegate;
- (void)removeDelegate:(id<UIScrollViewDelegate>)delegate;

@end


@interface UIScrollView ()

@property (readonly, nonatomic) ScrollViewDelegateMultiplexer *delegateMultiplexer;

@end


@implementation UIScrollView (DelegateExtras)

- (void)addDelegate:(id<UIScrollViewDelegate>)delegate {
    ScrollViewDelegateMultiplexer *multiplexer = self.delegateMultiplexer;
    
    [multiplexer addDelegate:delegate];
    
    // Ensure UIScrollView re-caches any `-respondsToSelector:` queries.
    self.delegate = nil;
    self.delegate = multiplexer;
}

- (void)removeDelegate:(id<UIScrollViewDelegate>)delegate {
    [self.delegateMultiplexer removeDelegate:delegate];
}

- (ScrollViewDelegateMultiplexer *)delegateMultiplexer {
    ScrollViewDelegateMultiplexer *multiplexer = objc_getAssociatedObject(self, _cmd);
    
    if (!multiplexer) {
        multiplexer = [[ScrollViewDelegateMultiplexer alloc] initWithScrollView:self];
        objc_setAssociatedObject(self, _cmd, multiplexer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return multiplexer;
}

@end


@implementation ScrollViewDelegateMultiplexer {
    NSPointerArray *_delegates;
}

- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    if ((self = [super init])) {
        _delegates = [NSPointerArray weakObjectsPointerArray];
        _scrollView = scrollView;
        
        [self addObserver:self
               forKeyPath:@"scrollView.contentSize"
                  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
                  context:KVOContext];
    }
    return self;
}

- (void)dealloc {
    _scrollView.delegate = nil;
    [self removeObserver:self forKeyPath:@"scrollView.contentSize" context:KVOContext];
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
    
    NSCParameterAssert(object == self);
    NSParameterAssert([keyPath isEqualToString:@"scrollView.contentSize"]);
    
    UIScrollView *scrollView = _scrollView;
    if (!scrollView) { return; }
    
    if (!([change[NSKeyValueChangeOldKey] isKindOfClass:[NSValue class]]
        && [change[NSKeyValueChangeNewKey] isKindOfClass:[NSValue class]]))
    {
        return;
    }
    
    CGSize oldSize = [change[NSKeyValueChangeOldKey] CGSizeValue];
    CGSize newSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
    if (CGSizeEqualToSize(oldSize, newSize)) {
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
}

- (BOOL)respondsToSelector:(SEL)selector {
    if ([super respondsToSelector:selector]) {
        return YES;
    }
    for (id<UIScrollViewDelegate> delegate in _delegates){
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
