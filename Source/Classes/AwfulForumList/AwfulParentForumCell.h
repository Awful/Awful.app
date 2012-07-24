//
//  AwfulParentForumCell.h
//  Awful
//
//  Created by me on 6/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulForumCell.h"
@class AwfulForum;

static NSString* const AwfulToggleExpandForum = @"com.regularberry.awful.notifications.toggleExpandForum";

@interface AwfulParentForumCell : AwfulForumCell
@property (nonatomic) BOOL isExpanded;
@end
