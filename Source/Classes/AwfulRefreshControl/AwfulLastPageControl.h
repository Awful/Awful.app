//
//  AwfulLastPageControl.h
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadNextControl.h"

@interface AwfulLastPageControl : AwfulLoadNextControl
@property (nonatomic,readonly,strong) UIView* autoRefreshView;
@property (nonatomic, readonly) BOOL autoRefreshEnabled;

@property (nonatomic,strong) NSTimer* refreshTimer;
@property (nonatomic,strong) NSTimer* updateUITimer;

@end
