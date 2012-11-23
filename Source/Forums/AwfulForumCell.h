//
//  AwfulForumCell.h
//  Awful
//
//  Created by Nolan Waite on 2012-09-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum
{
    AwfulForumCellShowsExpandedNever,
    AwfulForumCellShowsExpandedButton,
    AwfulForumCellShowsExpandedLeavesRoom
} AwfulForumCellShowsExpanded;


@interface AwfulForumCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (getter=isFavorite, nonatomic) BOOL favorite;

@property (nonatomic) BOOL showsFavorite;

@property (readonly, weak, nonatomic) UIButton *favoriteButton;

@property (getter=isExpanded, nonatomic) BOOL expanded;

@property (nonatomic) AwfulForumCellShowsExpanded showsExpanded;

@property (readonly, weak, nonatomic) UIButton *expandButton;

@end
