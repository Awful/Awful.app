//
//  AwfulScrollViewTopBar.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

// A view that sits atop a UIScrollView, appearing when scrolling up.
@interface AwfulScrollViewTopBar : UIView <UIScrollViewDelegate>

// Forward these UIScrollViewDelegate messages if this instance is not the scroll view's delegate.

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

@end
