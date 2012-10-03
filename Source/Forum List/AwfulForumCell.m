//
//  AwfulForumCell.m
//  Awful
//
//  Created by Nolan Waite on 2012-09-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"

@interface AwfulForumCell ()

@property (weak, nonatomic) UIButton *favoriteButton;

@end


@implementation AwfulForumCell

#pragma mark - Init

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        UITapGestureRecognizer *tapToExpand = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(toggleExpanded)];
        [self.imageView addGestureRecognizer:tapToExpand];
        self.imageView.userInteractionEnabled = YES;
        self.textLabel.font = [UIFont boldSystemFontOfSize:15];
        self.textLabel.numberOfLines = 2;
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

- (void)setShowsFavorite:(BOOL)showsFavorite
{
    if (_showsFavorite == showsFavorite) return;
    _showsFavorite = showsFavorite;
    if (showsFavorite) {
        if (!self.favoriteButton) {
            self.favoriteButton = CreateFavoriteButtonWithTarget(self);
            [self.contentView addSubview:self.favoriteButton];
        }
        self.favoriteButton.selected = self.favorite;
    } else {
        [self.favoriteButton removeFromSuperview];
    }
    [self setNeedsLayout];
}

static UIButton *CreateFavoriteButtonWithTarget(id target)
{
    UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [favoriteButton setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
    [favoriteButton setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateSelected];
    [favoriteButton addTarget:target
                       action:@selector(toggleFavorite)
             forControlEvents:UIControlEventTouchUpInside];
    favoriteButton.contentMode = UIViewContentModeCenter;
    [favoriteButton sizeToFit];
    CGRect bounds = favoriteButton.bounds;
    bounds.size.width += 40;
    favoriteButton.bounds = bounds;
    return favoriteButton;
}

- (void)toggleFavorite
{
    self.favorite = !self.favorite;
    if ([self.delegate respondsToSelector:@selector(forumCellDidToggleFavorite:)]) {
        [self.delegate forumCellDidToggleFavorite:self];
    }
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

static const CGFloat StarLeftMargin = 11;

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect textFrame = self.textLabel.frame;
    if (self.showsExpanded == AwfulForumCellShowsExpandedLeavesRoom) {
        textFrame.origin.x += 32;
        textFrame.size.width -= 32;
    }
    if (self.favoriteButton) {
        self.favoriteButton.center = CGPointMake(CGRectGetMaxX(textFrame) - StarLeftMargin,
                                                 CGRectGetMidY(textFrame));
        textFrame.size.width -= self.favoriteButton.imageView.bounds.size.width + StarLeftMargin;
    }
    self.textLabel.frame = textFrame;
}

@end
