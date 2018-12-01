//  UIScrollView+DelegateExtras.h
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIScrollView (DelegateExtras)

/**
 Enables delegate multiplexing for this scroll view and adds `delegate` as a receiver of delegate messages.
 
 In addition, delegates that conform to `ScrollViewDelegateExtras` can implement extra methods that will be called as appropriate while multiplexing is enabled.
 
 Maintains a weak reference to `delegate`.
 */
- (void)addDelegate:(id<UIScrollViewDelegate>)delegate;

/**
 Prevents `delegate` from receiving any further messages from this scroll view.
 
 Any delegates are removed when the scroll view deallocates, and weak references are held to all delegates, so there is no need to call `-removeDelegate:` before either the scroll view or the delegate deallocates. (Neither is there any harm in doing so.)
 */
- (void)removeDelegate:(id<UIScrollViewDelegate>)delegate;

@end


/**
 Extra delegate methods available when delegate multiplexing is enabled on a scroll view.
 
 @seealso `-[UIScrollView addDelegate:]`.
 */
@protocol ScrollViewDelegateExtras <UIScrollViewDelegate>

@optional

/**
 Tells the delegate when the scroll view's content size has changed.
 
 Fun fact: there's a private method `-scrollViewDidChangeContentSize:` that `UIScrollView` will call on its delegate, so we use a different name here to avoid even more funny business.
 */
- (void)awful_scrollViewDidChangeContentSize:(UIScrollView *)scrollView NS_SWIFT_NAME(scrollViewDidChangeContentSize(_:));

@end


@interface UICollectionView (DelegateExtras)

// Collection view requires a collection view delegate, but the implementation is agnostic, so this is just a heads-up for the programmer.

- (void)addDelegate:(id<UICollectionViewDelegate>)delegate;
- (void)removeDelegate:(id<UICollectionViewDelegate>)delegate;

@end


@interface UITableView (DelegateExtras)

// Table view requires a table view delegate, but the implementation is agnostic, so this is just a heads-up for the programmer.

- (void)addDelegate:(id<UITableViewDelegate>)delegate;
- (void)removeDelegate:(id<UITableViewDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
