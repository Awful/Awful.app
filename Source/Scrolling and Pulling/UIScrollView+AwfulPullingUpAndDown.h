//
//  UIScrollView+AwfulPullingUpAndDown.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPullToRefreshControl.h"

@interface UIScrollView (AwfulPullingUpAndDown)

@property (nonatomic) AwfulPullToRefreshControl *pullDownToRefreshControl;

@property (nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;

@end
