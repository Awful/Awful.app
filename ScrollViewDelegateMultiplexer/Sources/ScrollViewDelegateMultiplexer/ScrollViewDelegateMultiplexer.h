//  ScrollViewDelegateMultiplexer.h
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A scroll view delegate that forwards messages to multiple delegates.
 
 You'll need to keep a strong reference to the multiplexer. The multiplexer, however, only keeps weak references to its delegates.
 
 In addition, delegates that conform to `ScrollViewDelegateExtras` will get any implemented bonus methods called.
 
 `ScrollViewDelegateMultiplexer` conforms to `UICollectionViewDelegateFlowLayout` and `UITableViewDelegate` for convenience, and it will also forward those methods to each delegate.
 */
@interface ScrollViewDelegateMultiplexer : NSObject <UICollectionViewDelegateFlowLayout, UITableViewDelegate>

- (instancetype)initWithScrollView:(UIScrollView *)scrollView NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// A weak reference is kept to `delegate`.
- (void)addDelegate:(id<UIScrollViewDelegate>)delegate NS_SWIFT_NAME(addDelegate(_:));
- (void)removeDelegate:(id<UIScrollViewDelegate>)delegate NS_SWIFT_NAME(removeDelegate(_:));

@end


/**
 Extra delegate methods available when using a scroll view delegate multiplexer.
 
 @seealso `ScrollViewDelegateMultiplexer`.
 */
@protocol ScrollViewDelegateExtras <UIScrollViewDelegate>

@optional

/**
 Tells the delegate when the scroll view's content size has changed.
 
 Fun fact: there's a private method `-scrollViewDidChangeContentSize:` that `UIScrollView` will call on its delegate, so we use a different name here to avoid even more funny business.
 */
- (void)awful_scrollViewDidChangeContentSize:(UIScrollView *)scrollView NS_SWIFT_NAME(scrollViewDidChangeContentSize(_:));

@end

NS_ASSUME_NONNULL_END
