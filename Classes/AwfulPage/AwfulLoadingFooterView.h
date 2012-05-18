//
//  AwfulPullToNavigateView.h
//  Awful
//
//  Created by me on 5/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "EGORefreshTableHeaderView.h"
#import "AwfulPullForActionController.h"

@interface AwfulLoadingFooterView : UITableViewCell <AwfulPullForActionViewDelegate>

@property (nonatomic,readwrite) BOOL onLastPage;
@property (nonatomic,strong) IBOutlet UISwitch* autoF5;
@property (nonatomic,strong) UIScrollView* scrollView;

@property (readonly) IBOutlet UILabel* mainLabel;
@property (readonly) IBOutlet UILabel* subLabel;


@end
