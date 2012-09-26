//
//  AwfulForumCell.m
//  Awful
//
//  Created by Nolan Waite on 2012-09-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"

@interface AwfulForumCell ()

@property (readonly, nonatomic) UIButton *favoriteButton;

@end

@implementation AwfulForumCell

#pragma mark - Init

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.numberOfLines = 0;
        UITapGestureRecognizer *tapToExpand = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(toggleExpanded)];
        [self.imageView addGestureRecognizer:tapToExpand];
        self.imageView.userInteractionEnabled = YES;
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

#pragma mark - Favorite

- (void)setFavorite:(BOOL)isFavorite
{
    if (_favorite == isFavorite) return;
    _favorite = isFavorite;
    self.favoriteButton.selected = isFavorite;
}

static UIButton *CreateFavoriteButton(id target)
{
    UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [favoriteButton setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
    [favoriteButton setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateSelected];
    [favoriteButton addTarget:target
                       action:@selector(toggleFavorite)
             forControlEvents:UIControlEventTouchUpInside];
    [favoriteButton sizeToFit];
    return favoriteButton;
}

- (void)setShowsFavorite:(BOOL)showsFavorite
{
    if (_showsFavorite == showsFavorite) return;
    _showsFavorite = showsFavorite;
    if (showsFavorite) {
        self.accessoryView = CreateFavoriteButton(self);
        self.favoriteButton.selected = self.favorite;
    } else {
        self.accessoryView = nil;
    }
}

- (void)toggleFavorite
{
    self.favorite = !self.favorite;
    if ([self.delegate respondsToSelector:@selector(forumCellDidToggleFavorite:)]) {
        [self.delegate forumCellDidToggleFavorite:self];
    }
}

- (UIButton *)favoriteButton
{
    return (UIButton *)self.accessoryView;
}

#pragma mark - Expanded

- (void)setExpanded:(BOOL)expanded
{
    if (_expanded == expanded) return;
    _expanded = expanded;
    if (self.showsExpanded) {
        [self updateExpandedImage];
        if ([self.delegate respondsToSelector:@selector(forumCellDidToggleExpanded:)]) {
            [self.delegate forumCellDidToggleExpanded:self];
        }
    }
}

- (void)setShowsExpanded:(AwfulForumCellShowsExpanded)showsExpanded
{
    if (_showsExpanded == showsExpanded) return;
    _showsExpanded = showsExpanded;
    if (showsExpanded == AwfulForumCellShowsExpandedButton) {
        [self updateExpandedImage];
    } else {
        self.imageView.image = nil;
    }
}

- (void)updateExpandedImage
{
    if (self.expanded) {
        self.imageView.image = [UIImage imageNamed:@"forum-arrow-down.png"];
    } else {
        self.imageView.image = [UIImage imageNamed:@"forum-arrow-right.png"];
    }
}

- (void)toggleExpanded
{
    self.expanded = !self.expanded;
}

#pragma mark - Size and layout

+ (CGFloat)heightForCellWithText:(NSString *)text
                        fontSize:(CGFloat)fontSize
                   showsFavorite:(BOOL)showsFavorite
                   showsExpanded:(AwfulForumCellShowsExpanded)showsExpanded
                      tableWidth:(CGFloat)tableWidth
{
    CGFloat width = tableWidth;
    if (showsExpanded != AwfulForumCellShowsExpandedNever) {
        width -= 42;
    }
    if (showsFavorite) {
        width -= 50;
    }
    CGSize textSize = [text sizeWithFont:[UIFont boldSystemFontOfSize:fontSize]
                       constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)];
    // TODO figure out why cells with 3 lines have too much top/bottom padding, while cells with
    // < 3 lines are fine.
    CGFloat offset = textSize.height > 80 ? -10 : 0;
    return MAX(textSize.height + offset + 26, 50);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.showsExpanded == AwfulForumCellShowsExpandedLeavesRoom) {
        CGRect frame = self.textLabel.frame;
        frame.origin.x += 32;
        frame.size.width -= 32;
        self.textLabel.frame = frame;
    }
}

@end
