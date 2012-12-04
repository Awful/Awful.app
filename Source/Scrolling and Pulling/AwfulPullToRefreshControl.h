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
- (id)initWithDirection:(AwfulScrollViewPullDirection)direction;

@property (readonly, nonatomic) AwfulScrollViewPullDirection direction;

// Number of points to drag the scroll view **beyond this control's height** before the refresh
// is triggered. Default is 0.
@property (nonatomic) CGFloat triggerOffset;

@property (getter=isRefreshing, nonatomic) BOOL refreshing;

- (void)setRefreshing:(BOOL)refreshing animated:(BOOL)animated;

// By default, titles are set for:
//     - UIControlStateNormal
//     - UIControlStateSelected (i.e. dragged far enough to refresh if released)
//     - AwfulControlStateRefreshing.
//
// If no title has been set for the given state, returns the title for UIControlStateNormal.
- (NSString *)titleForState:(UIControlState)state;

- (void)setTitle:(NSString *)title forState:(UIControlState)state;

@end

enum {
    // AwfulPullToRefreshControl's state includes this bit when refreshing.
    AwfulControlStateRefreshing = 1 << 16
};
