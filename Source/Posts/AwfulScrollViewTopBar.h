//
//  AwfulScrollViewTopBar.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <UIKit/UIKit.h>

// A view that sits atop a UIScrollView, appearing when scrolling up.
@interface AwfulScrollViewTopBar : UIView <UIScrollViewDelegate>

// Forward these UIScrollViewDelegate messages if this instance is not the scroll view's delegate.

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

@end
