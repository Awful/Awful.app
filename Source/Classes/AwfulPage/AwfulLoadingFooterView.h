//
//  AwfulPullToNavigateView.h
//  Awful
//
//  Created by me on 5/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "EGORefreshTableHeaderView.h"
#import "AwfulPullForActionController.h"

typedef enum {
    AwfulPullForActionOnLastPage = 5,
    AwfulPullForActionAutoF5 = 50
} AwfulPullForActionPageState;

@interface AwfulLoadingFooterView : UITableViewCell <AwfulPullForActionViewDelegate>

@property (nonatomic,readwrite) BOOL onLastPage;
@property (nonatomic,weak) IBOutlet UISwitch* autoF5;
//@property (nonatomic,strong) UIScrollView* scrollView;
@property (nonatomic,strong) NSDate* loadedDate;
@property (readonly) NSString* stringTimeIntervalSinceLoad;


@end
