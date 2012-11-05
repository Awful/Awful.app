//
//  AwfulPullToRefreshControl.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulScrollViewPullObserver.h"

// Sends UIControlEventValueChanged when a refresh should occur.
@interface AwfulPullToRefreshControl : UIControl

// Designated initializer.
- (id)initWithScrollView:(UIScrollView *)scrollView
               direction:(AwfulScrollViewPullDirection)direction;

@property (readonly, nonatomic) UIScrollView *scrollView;

@property (readonly, nonatomic) AwfulScrollViewPullDirection direction;

@property (getter=isRefreshing, nonatomic) BOOL refreshing;

- (void)setRefreshing:(BOOL)refreshing animated:(BOOL)animated;

// If no title has been set for the given state, returns the title for UIControlStateNormal.
//
// By default, titles are set for:
//     - UIControlStateNormal
//     - UIControlStateSelected (i.e. dragged far enough to refresh if released)
//     - AwfulControlStateRefreshing.
- (void)setTitle:(NSString *)title forState:(UIControlState)state;

@end

enum {
    // AwfulPullToRefreshControl's state includes this bit when refreshing.
    AwfulControlStateRefreshing = 1 << 16
};
