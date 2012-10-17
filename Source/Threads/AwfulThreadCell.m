//
//  AwfulThreadCell.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-02.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadCell.h"

@interface AwfulThreadCell ()

@property (weak, nonatomic) UIImageView *stickyImageView;

@property (readonly, weak, nonatomic) UIImageView *ratingImageView;

@end

@implementation AwfulThreadCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.numberOfLines = 3;
        self.textLabel.font = [UIFont systemFontOfSize:15];
        self.detailTextLabel.font = [UIFont systemFontOfSize:11];
        self.imageView.layer.borderColor = [UIColor blackColor].CGColor;
        self.imageView.layer.borderWidth = 1;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        UIImageView *stickyImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sticky.png"]];
        [self.contentView addSubview:stickyImageView];
        _stickyImageView = stickyImageView;
        
        UIImageView *ratingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 45, 13)];
        [self.contentView addSubview:ratingImageView];
        _ratingImageView = ratingImageView;
        
        UILabel *originalPosterTextLabel = [UILabel new];
        originalPosterTextLabel.backgroundColor = [UIColor clearColor];
        originalPosterTextLabel.font = self.detailTextLabel.font;
        originalPosterTextLabel.textColor = [self originalPosterTextColor];
        [self.contentView addSubview:originalPosterTextLabel];
        _originalPosterTextLabel = originalPosterTextLabel;
        
        AwfulBadgeView *unreadCountBadgeView = [[AwfulBadgeView alloc] initWithCell:self];
        [self.contentView addSubview:unreadCountBadgeView];
        _unreadCountBadgeView = unreadCountBadgeView;
        _showsUnread = YES;
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (UIImageView *)threadTagImageView
{
    return self.imageView;
}

- (void)setSticky:(BOOL)sticky
{
    self.stickyImageView.hidden = !sticky;
}

- (void)setRating:(CGFloat)rating
{
    self.ratingImageView.hidden = rating < 1;
    if (self.ratingImageView.hidden) return;
    NSInteger ratingImageNumber = lroundf(rating);
    ratingImageNumber = MAX(1, ratingImageNumber);
    ratingImageNumber = MIN(ratingImageNumber, 5);
    self.ratingImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"rating%d.png",
                                                      ratingImageNumber]];
}

- (void)setShowsUnread:(BOOL)showsUnread
{
    if (_showsUnread == showsUnread) return;
    _showsUnread = showsUnread;
    if (!(self.editing || self.showingDeleteConfirmation))
        self.unreadCountBadgeView.hidden = !showsUnread;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize cellSize = self.contentView.bounds.size;
    
    // Center tag image view and rating image view (if visible) as a unit and align them on the left.
    // Sticky goes over bottom right corner of tag.
    CGRect ratingImageFrame = self.ratingImageView.frame;
    CGFloat effectiveRatingHeight = self.ratingImageView.hidden ? 0 : ratingImageFrame.size.height + 2;
    static const CGFloat tagWidth = 45;
    self.threadTagImageView.frame = (CGRect){
        .origin.x = 4,
        .origin.y = (cellSize.height - tagWidth - effectiveRatingHeight) / 2,
        .size = CGSizeMake(tagWidth, tagWidth)
    };
    if (!self.stickyImageView.hidden) {
        CGRect stickyImageFrame = self.stickyImageView.frame;
        stickyImageFrame.origin.x = CGRectGetMaxX(self.threadTagImageView.frame) - stickyImageFrame.size.width + 1;
        stickyImageFrame.origin.y = CGRectGetMaxY(self.threadTagImageView.frame) - stickyImageFrame.size.height + 1;
        self.stickyImageView.frame = stickyImageFrame;
    }
    if (!self.ratingImageView.hidden) {
        ratingImageFrame.origin.x = CGRectGetMidX(self.threadTagImageView.frame) - ratingImageFrame.size.width / 2;
        ratingImageFrame.origin.y = CGRectGetMaxY(self.threadTagImageView.frame) + 2;
        self.ratingImageView.frame = ratingImageFrame;
    }
    
    // Align badge view right horizontally, center vertically.
    [self.unreadCountBadgeView sizeToFit];
    CGRect unreadCountFrame = self.unreadCountBadgeView.frame;
    unreadCountFrame.origin.x = cellSize.width - 10 - unreadCountFrame.size.width;
    unreadCountFrame.origin.y = (cellSize.height - unreadCountFrame.size.height) / 2;
    self.unreadCountBadgeView.frame = unreadCountFrame;
    
    // Align text and detail text labels beside the thread tag, centered vertically as a unit.
    // Detail text label and original poster text label go beside one another horizontally.
    CGRect textLabelFrame = self.textLabel.frame;
    CGRect detailTextLabelFrame = self.detailTextLabel.frame;
    static CGFloat const tagRightMargin = 9;
    CGFloat textOriginX = CGRectGetMaxX(self.threadTagImageView.frame) + tagRightMargin;
    CGFloat badgeViewEffectiveWidth = (self.editing || self.showingDeleteConfirmation) ? tagRightMargin : 70;
    CGSize constraint = CGSizeMake(cellSize.width - textOriginX - badgeViewEffectiveWidth,
                                   58);
    CGSize textSize = [self.textLabel.text sizeWithFont:self.textLabel.font
                                      constrainedToSize:constraint];
    CGFloat detailVerticalOffset = CGRectGetMinY(detailTextLabelFrame) - CGRectGetMaxY(textLabelFrame);
    textLabelFrame.origin.x = textOriginX;
    detailTextLabelFrame.origin.x = textOriginX;
    textLabelFrame.size = textSize;
    textLabelFrame.origin.y = (self.contentView.bounds.size.height - textSize.height - detailTextLabelFrame.size.height) / 2 - detailVerticalOffset;
    textLabelFrame = CGRectIntegral(textLabelFrame);
    detailTextLabelFrame.origin.y = CGRectGetMaxY(textLabelFrame) + detailVerticalOffset;
    
    self.textLabel.frame = textLabelFrame;
    self.detailTextLabel.frame = detailTextLabelFrame;
    
    [self.detailTextLabel sizeToFit];
    static const CGFloat detailRightMargin = 5;
    self.originalPosterTextLabel.frame = (CGRect){
        .origin.x = CGRectGetMaxX(detailTextLabelFrame) + detailRightMargin,
        .origin.y = detailTextLabelFrame.origin.y,
        .size.width = textLabelFrame.size.width - detailTextLabelFrame.size.width - detailRightMargin
    };
    [self.originalPosterTextLabel sizeToFit];
}

- (UIColor *)originalPosterTextColor
{
    return [UIColor colorWithHue:0.553 saturation:0.198 brightness:0.659 alpha:1];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    self.originalPosterTextLabel.textColor = highlighted ? [UIColor whiteColor] : [self originalPosterTextColor];
    [self.unreadCountBadgeView setNeedsDisplay];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    self.originalPosterTextLabel.textColor = selected ? [UIColor whiteColor] : [self originalPosterTextColor];
    [self.unreadCountBadgeView setNeedsDisplay];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (self.showsUnread) {
        self.unreadCountBadgeView.hidden = editing;
    }
}

- (void)willTransitionToState:(UITableViewCellStateMask)state
{
    [super willTransitionToState:state];
    
    if (state & UITableViewCellStateShowingDeleteConfirmationMask) {
        self.unreadCountBadgeView.hidden = YES;
    } else {
        if (self.showsUnread) {
            self.unreadCountBadgeView.hidden = NO;
        }
    }
}

@end
