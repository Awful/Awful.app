//
//  AwfulForumCell.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
