//
//  AwfulLoadingHeaderView.h
//  Awful
//
//  Created by me on 6/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPullForActionController.h"
#import "AwfulLoadingFooterView.h"

@interface AwfulLoadingHeaderView : AwfulLoadingFooterView <AwfulPullForActionViewDelegate>

@property (nonatomic,strong) NSDate* loadedDate;
@property (readonly) NSString* stringTimeIntervalSinceLoad;
@property (nonatomic,strong) SRRefreshView* test;
@end
