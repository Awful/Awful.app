//
//  AwfulLoadingHeaderView.h
//  Awful
//
//  Created by me on 6/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "EGORefreshTableHeaderView.h"
#import "AwfulPullForActionController.h"

@interface AwfulLoadingHeaderView : EGORefreshTableHeaderView <AwfulPullForActionViewDelegate>

@property (nonatomic,strong) NSDate* loadedDate;
@property (readonly) NSString* stringTimeIntervalSinceLoad;
@end
