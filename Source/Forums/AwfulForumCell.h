//
//  AwfulForumCell.h
//  Awful
//
//  Created by Nolan Waite on 2012-09-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AwfulForumCellDelegate;

typedef enum
{
    AwfulForumCellShowsExpandedNever,
    AwfulForumCellShowsExpandedButton,
    AwfulForumCellShowsExpandedLeavesRoom
} AwfulForumCellShowsExpanded;


@interface AwfulForumCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (weak, nonatomic) id <AwfulForumCellDelegate> delegate;

@property (getter=isFavorite, nonatomic) BOOL favorite;

@property (nonatomic) BOOL showsFavorite;

@property (getter=isExpanded, nonatomic) BOOL expanded;

@property (nonatomic) AwfulForumCellShowsExpanded showsExpanded;

@end


@protocol AwfulForumCellDelegate <NSObject>
@optional

- (void)forumCellDidToggleFavorite:(AwfulForumCell *)cell;

- (void)forumCellDidToggleExpanded:(AwfulForumCell *)cell;

@end
