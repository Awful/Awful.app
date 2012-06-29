//
//  AwfulForumCell.h
//  Awful
//
//  Created by me on 6/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulForumCell : UITableViewCell

@property (nonatomic,strong) AwfulForum* forum;

-(void) setFavoriteButtonAccessory;
+(CGFloat) heightForContent:(AwfulForum*)forum inTableView:(UITableView*)tableView;
@end
