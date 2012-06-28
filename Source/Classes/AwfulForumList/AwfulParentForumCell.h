//
//  AwfulParentForumCell.h
//  Awful
//
//  Created by me on 6/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulForum;

static NSString* const AwfulToggleExpandForum = @"com.regularberry.awful.notifications.toggleExpandForum";

@interface AwfulParentForumCell : UITableViewCell
@property (nonatomic,strong) AwfulForum* forum;
@property (nonatomic) BOOL isExpanded;
@end
