//
//  AwfulSubForumCell.m
//  Awful
//
//  Created by me on 6/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSubForumCell.h"

@implementation AwfulSubForumCell

-(void) setForum:(AwfulForum *)forum {
    [super setForum:forum];
    self.indentationLevel = 1;
    self.indentationWidth = 60;
    self.textLabel.font = [UIFont boldSystemFontOfSize:15];
    self.detailTextLabel.font = [UIFont systemFontOfSize:12];
    [self setFavoriteButtonAccessory];
}

+ (CGFloat)heightForContent:(AwfulForum *)forum inTableView:(UITableView *)tableView
{
    int width = tableView.frame.size.width - 20 - 50 - 60;
    int height = 44;
    CGSize textSize = [forum.name sizeWithFont:[UIFont boldSystemFontOfSize:15]
                             constrainedToSize:CGSizeMake(width, 4000)
                                 lineBreakMode:UILineBreakModeWordWrap];
    height = 10 + textSize.height;
    return MAX(height, 50);
}

@end
