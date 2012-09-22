//
//  AwfulParentForumCell.m
//  Awful
//
//  Created by me on 6/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParentForumCell.h"

@implementation AwfulParentForumCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(toggle)];
    [self.imageView addGestureRecognizer:tap];
}

- (void)toggle
{
    self.expanded = !self.expanded;
    [self.delegate parentForumCellDidToggleExpansion:self];
    if (self.expanded)
        self.imageView.image = [UIImage imageNamed:@"forum-arrow-down.png"];
    else
        self.imageView.image = [UIImage imageNamed:@"forum-arrow-right.png"];
}

- (void)setForum:(AwfulForum *)forum
{
    [super setForum:forum];
    self.expanded = forum.expandedValue;
    [self setFavoriteButtonAccessory];
    self.imageView.image = [UIImage imageNamed:@"forum-arrow-right.png"];
}

+ (CGFloat)heightForContent:(AwfulForum *)forum inTableView:(UITableView *)tableView
{
    int width = tableView.frame.size.width - 40 - 55;
    int height = 44;
    CGSize textSize = [forum.name sizeWithFont:[UIFont boldSystemFontOfSize:18]
                             constrainedToSize:CGSizeMake(width, 4000)
                                 lineBreakMode:UILineBreakModeWordWrap];
    height = 10 + textSize.height;
    return MAX(height, 50);
}

@end
