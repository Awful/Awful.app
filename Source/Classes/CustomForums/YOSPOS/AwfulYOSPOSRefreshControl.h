//
//  AwfulYOSPOSRefreshControl.h
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulRefreshControl.h"
@class AwfulYOSPOSFakeShell;

@interface AwfulYOSPOSRefreshControl : AwfulRefreshControl
@property (nonatomic,readonly) AwfulYOSPOSFakeShell* shell;
@property (nonatomic) UIScrollView* scrollView;
@end