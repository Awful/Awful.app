//
//  AwfulScrollViewPullObserver.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulScrollViewPullObserver : NSObject

typedef enum {
    AwfulScrollViewPullDown,
    AwfulScrollViewPullUp
} AwfulScrollViewPullDirection;

typedef void (^AwfulPullToRefreshBlock)(void);

// Designated initializer.
- (id)initWithScrollView:(UIScrollView *)scrollView
               direction:(AwfulScrollViewPullDirection)direction
           triggerOffset:(CGFloat)triggerOffset;

@property (readonly, weak, nonatomic) UIScrollView *scrollView;

@property (readonly, nonatomic) AwfulScrollViewPullDirection direction;

@property (nonatomic) CGFloat triggerOffset;

@property (copy, nonatomic) AwfulPullToRefreshBlock willTrigger;

@property (copy, nonatomic) AwfulPullToRefreshBlock willNotTrigger;

@property (copy, nonatomic) AwfulPullToRefreshBlock didTrigger;

@property (copy, nonatomic) AwfulPullToRefreshBlock scrollViewDidResize;

- (void)reset;

- (void)willLeaveScrollView:(UIScrollView *)scrollView;

@end
