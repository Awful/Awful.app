//
//  UIScrollView+AwfulPullingUpAndDown.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UIScrollView+AwfulPullingUpAndDown.h"
#import <objc/runtime.h>

@implementation UIScrollView (AwfulPullingUpAndDown)

- (AwfulPullToRefreshControl *)pullDownToRefreshControl
{
    AwfulPullToRefreshControl *control = objc_getAssociatedObject(self, &PullDownControlKey);
    if (!control) {
        control = [[AwfulPullToRefreshControl alloc] initWithScrollView:self
                                                              direction:AwfulScrollViewPullDown];
        [self addSubview:control];
        self.pullDownToRefreshControl = control;
    }
    return control;
}

- (void)setPullDownToRefreshControl:(UIControl *)pullDownToRefreshControl
{
    [self willChangeValueForKey:@"pullDownToRefreshControl"];
    objc_setAssociatedObject(self, &PullDownControlKey, pullDownToRefreshControl,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"pullDownToRefreshControl"];
}

static const void * PullDownControlKey = @"Awful pull down control";

- (AwfulPullToRefreshControl *)pullUpToRefreshControl
{
    AwfulPullToRefreshControl *control = objc_getAssociatedObject(self, &PullUpControlKey);
    if (!control) {
        control = [[AwfulPullToRefreshControl alloc] initWithScrollView:self
                                                              direction:AwfulScrollViewPullUp];
        [self addSubview:control];
        self.pullUpToRefreshControl = control;
    }
    return control;
}

- (void)setPullUpToRefreshControl:(UIControl *)pullUpToRefreshControl
{
    [self willChangeValueForKey:@"pullUpToRefreshControl"];
    objc_setAssociatedObject(self, &PullUpControlKey, pullUpToRefreshControl,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"pullUpToRefreshControl"];
}

static const void * PullUpControlKey = @"Awful pull up control";

@end
