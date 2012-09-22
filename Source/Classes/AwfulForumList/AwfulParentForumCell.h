//
//  AwfulParentForumCell.h
//  Awful
//
//  Created by me on 6/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulForumCell.h"

@protocol AwfulParentForumCellDelegate;

@interface AwfulParentForumCell : AwfulForumCell

@property (weak, nonatomic) id <AwfulParentForumCellDelegate> delegate;
@property (getter=isExpanded, nonatomic) BOOL expanded;

@end

@protocol AwfulParentForumCellDelegate <NSObject>

@required
- (void)parentForumCellDidToggleExpansion:(AwfulParentForumCell *)cell;

@end
