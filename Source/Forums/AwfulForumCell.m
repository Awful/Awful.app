//
//  AwfulForumCell.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulForumCell.h"
#import "AwfulTheme.h"

@interface AwfulForumCell ()

@property (weak, nonatomic) UIButton *expandButton;

@property (weak, nonatomic) UIButton *favoriteButton;

@end


@implementation AwfulForumCell

#pragma mark - Init

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        UIButton *expandButton = [UIButton new];
        expandButton.contentMode = UIViewContentModeCenter;
        [self updateExpandButtonAccessibilityLabel];
        [self.contentView addSubview:expandButton];
        _expandButton = expandButton;
        
        UIButton *favoriteButton = [UIButton new];
        favoriteButton.contentMode = UIViewContentModeCenter;
        favoriteButton.hidden = YES;
        [self updateFavoriteButtonAccessibilityLabel];
        [self.contentView addSubview:favoriteButton];
        _favoriteButton = favoriteButton;
        
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
    _favorite = isFavorite;
    self.favoriteButton.selected = isFavorite;
    [self updateFavoriteButtonAccessibilityLabel];
}


- (BOOL)showsFavorite
{
    return !self.favoriteButton.hidden;
}

- (void)setShowsFavorite:(BOOL)showsFavorite
{
    if (showsFavorite == !self.favoriteButton.hidden) return;
    self.favoriteButton.hidden = !showsFavorite;
    [self setNeedsLayout];
}

- (void)updateFavoriteButtonAccessibilityLabel
{
    if (self.favoriteButton.selected) {
        self.favoriteButton.accessibilityLabel = @"Remove from favorites";
    } else {
        self.favoriteButton.accessibilityLabel = @"Add to favorites";
    }
}

#pragma mark - Expanded

- (BOOL)isExpanded
{
    return self.expandButton.selected;
}

- (void)setExpanded:(BOOL)expanded
{
    if (expanded == self.expandButton.selected) return;
    self.expandButton.selected = expanded;
}

- (void)updateExpandButtonAccessibilityLabel
{
    if (self.expandButton.selected) {
        self.expandButton.accessibilityLabel = @"Hide subforums";
    } else {
        self.expandButton.accessibilityLabel = @"List subforums";
    }
}

- (void)setShowsExpanded:(AwfulForumCellShowsExpanded)showsExpanded
{
    if (_showsExpanded == showsExpanded) return;
    _showsExpanded = showsExpanded;
    self.expandButton.hidden = showsExpanded != AwfulForumCellShowsExpandedButton;
}

#pragma mark - UITableViewCell

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self.accessoryView setNeedsDisplay];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self.accessoryView setNeedsDisplay];
}

#pragma mark - UIView

static const CGFloat StarLeftMargin = 11;

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect textFrame = self.textLabel.frame;
    if (self.showsExpanded == AwfulForumCellShowsExpandedNever) {
        self.expandButton.frame = CGRectZero;
    } else {
        self.expandButton.frame = CGRectMake(0, 0, 40, self.contentView.bounds.size.height);
        CGFloat newOriginX = CGRectGetMaxX(self.expandButton.frame) + 4;
        textFrame.size.width -= newOriginX - textFrame.origin.x;
        textFrame.origin.x = newOriginX;
    }
    if (self.showsFavorite) {
        [self.favoriteButton sizeToFit];
        CGRect bounds = self.favoriteButton.bounds;
        bounds.size.width += 40;
        self.favoriteButton.bounds = bounds;
        self.favoriteButton.center = CGPointMake(CGRectGetMaxX(textFrame) - StarLeftMargin,
                                                 CGRectGetMidY(textFrame));
        textFrame.size.width -= self.favoriteButton.imageView.bounds.size.width + StarLeftMargin;
    }
    self.textLabel.frame = textFrame;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.favoriteButton.hidden) {
        CGRect buttonRect = [self convertRect:self.favoriteButton.frame
                                     fromView:self.favoriteButton.superview];
        buttonRect = CGRectInset(buttonRect, -CGRectGetMaxX(self.bounds) + CGRectGetMaxX(buttonRect), 0);
        if (CGRectContainsPoint(buttonRect, point)) {
            return self.favoriteButton;
        }
    }
    return [super hitTest:point withEvent:event];
}

@end
