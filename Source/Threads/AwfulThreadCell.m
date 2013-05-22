//
//  AwfulThreadCell.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulThreadCell.h"
#import "AwfulThreadTagView.h"

@interface AwfulThreadCell ()

@property (nonatomic) AwfulThreadTagView *tagView;
@property (weak, nonatomic) UIImageView *stickyImageView;
@property (weak, nonatomic) UIImageView *ratingImageView;

@property (nonatomic) UIColor *oldOriginalPosterTextColor;

@end


@implementation AwfulThreadCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.numberOfLines = 2;
        self.textLabel.font = [UIFont systemFontOfSize:15];
        self.detailTextLabel.font = [UIFont systemFontOfSize:11];
        self.tagView = [AwfulThreadTagView new];
        self.tagView.layer.borderColor = [UIColor blackColor].CGColor;
        self.tagView.layer.borderWidth = 1;
        [self.contentView addSubview:self.tagView];
        
        UIImageView *stickyImageView = [UIImageView new];
        [self.contentView addSubview:stickyImageView];
        _stickyImageView = stickyImageView;
        
        UIImageView *ratingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 45, 13)];
        [self.contentView addSubview:ratingImageView];
        _ratingImageView = ratingImageView;
        
        UILabel *originalPosterTextLabel = [UILabel new];
        originalPosterTextLabel.backgroundColor = [UIColor clearColor];
        originalPosterTextLabel.font = self.detailTextLabel.font;
        [self.contentView addSubview:originalPosterTextLabel];
        _originalPosterTextLabel = originalPosterTextLabel;
        
        AwfulBadgeView *unreadCountBadgeView = [[AwfulBadgeView alloc] initWithCell:self];
        [self.contentView addSubview:unreadCountBadgeView];
        _unreadCountBadgeView = unreadCountBadgeView;
        _showsUnread = YES;
    }
    return self;
}

- (UIImage *)icon
{
    return self.tagView.tagImage;
}

- (void)setIcon:(UIImage *)icon
{
    self.tagView.tagImage = icon;
    self.tagView.hidden = !icon;
    [self setNeedsLayout];
}

- (UIImage *)secondaryIcon
{
    return self.tagView.secondaryTagImage;
}

- (void)setSecondaryIcon:(UIImage *)secondaryIcon
{
    self.tagView.secondaryTagImage = secondaryIcon;
}

- (CGFloat)iconAlpha
{
    return self.tagView.alpha;
}

- (void)setIconAlpha:(CGFloat)iconAlpha
{
    self.tagView.alpha = iconAlpha;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (void)setRating:(CGFloat)rating
{
    _rating = rating;
    self.ratingImageView.hidden = rating < 1;
    if (self.ratingImageView.hidden) {
        self.ratingImageView.image = nil;
    } else {
        NSInteger ratingImageNumber = lroundf(rating);
        ratingImageNumber = MAX(1, ratingImageNumber);
        ratingImageNumber = MIN(ratingImageNumber, 5);
        self.ratingImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"rating%d.png",
                                                          ratingImageNumber]];
    }
    [self setNeedsLayout];
}

- (void)setClosed:(BOOL)closed
{
    _closed = closed;
    self.textLabel.textColor = closed ? [UIColor grayColor] : [UIColor blackColor];
}

- (void)setShowsUnread:(BOOL)showsUnread
{
    _showsUnread = showsUnread;
    if (!(self.editing || self.showingDeleteConfirmation))
        self.unreadCountBadgeView.hidden = !showsUnread;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize cellSize = self.contentView.bounds.size;
    
    if (self.tagView.tagImage) {
        // Center tag image view and rating image view (if visible) as a unit and align them on the
        // left. Sticky goes over bottom right corner of tag.
        CGRect ratingImageFrame = self.ratingImageView.frame;
        CGFloat effectiveRatingHeight = self.ratingImageView.hidden ? 0 :
        ratingImageFrame.size.height + 2;
        static const CGFloat tagWidth = 45;
        self.tagView.frame = (CGRect){
            .origin.x = 4,
            .origin.y = (cellSize.height - tagWidth - effectiveRatingHeight) / 2,
            .size = CGSizeMake(tagWidth, tagWidth)
        };
        if (!self.stickyImageView.hidden) {
            [self.stickyImageView sizeToFit];
            CGRect stickyImageFrame = self.stickyImageView.frame;
            stickyImageFrame.origin.x = CGRectGetMaxX(self.tagView.frame) -
            stickyImageFrame.size.width + self.stickyImageViewOffset.width;
            stickyImageFrame.origin.y = CGRectGetMaxY(self.tagView.frame) -
            stickyImageFrame.size.height + self.stickyImageViewOffset.height;
            self.stickyImageView.frame = stickyImageFrame;
            [self.contentView insertSubview:self.stickyImageView aboveSubview:self.tagView];
        }
        if (!self.ratingImageView.hidden) {
            ratingImageFrame.origin.x = CGRectGetMidX(self.tagView.frame) -
            ratingImageFrame.size.width / 2;
            ratingImageFrame.origin.y = CGRectGetMaxY(self.tagView.frame) + 2;
            self.ratingImageView.frame = ratingImageFrame;
        }
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
    static const CGFloat tagRightMargin = 9;
    CGFloat textOriginX = 5;
    if (self.tagView.tagImage) textOriginX = CGRectGetMaxX(self.tagView.frame) + tagRightMargin;
    CGFloat badgeViewEffectiveWidth = CGRectGetWidth(unreadCountFrame) + tagRightMargin;
    if (self.editing || self.showingDeleteConfirmation || !self.showsUnread) {
        badgeViewEffectiveWidth = tagRightMargin;
    }
    CGSize constraint = CGSizeMake(cellSize.width - textOriginX - badgeViewEffectiveWidth,
                                   self.textLabel.numberOfLines * self.textLabel.font.leading);
    CGSize textSize = [self.textLabel.text sizeWithFont:self.textLabel.font
                                      constrainedToSize:constraint];
    CGFloat detailVerticalOffset = CGRectGetMinY(detailTextLabelFrame) -
    CGRectGetMaxY(textLabelFrame);
    textLabelFrame.origin.x = textOriginX;
    detailTextLabelFrame.origin.x = textOriginX;
    textLabelFrame.size = textSize;
    textLabelFrame.origin.y = (self.contentView.bounds.size.height - textSize.height -
                               detailTextLabelFrame.size.height) / 2 - detailVerticalOffset;
    textLabelFrame = CGRectIntegral(textLabelFrame);
    detailTextLabelFrame.origin.y = CGRectGetMaxY(textLabelFrame) + detailVerticalOffset;
    
    self.textLabel.frame = textLabelFrame;
    self.detailTextLabel.frame = detailTextLabelFrame;
    
    [self.detailTextLabel sizeToFit];
    static const CGFloat detailRightMargin = 5;
    CGRect originalPosterFrame = self.detailTextLabel.frame;
    originalPosterFrame.origin.x = CGRectGetMaxX(detailTextLabelFrame) + detailRightMargin;
    originalPosterFrame.size.width = cellSize.width - CGRectGetMaxX(detailTextLabelFrame);
    originalPosterFrame.size.width -= detailRightMargin;
    if (self.showsUnread) {
        originalPosterFrame.size.width -= (cellSize.width - unreadCountFrame.origin.x);
    }
    self.originalPosterTextLabel.frame = originalPosterFrame;
}

#pragma mark - UITableViewCell

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (highlighted) {
        self.oldOriginalPosterTextColor = self.originalPosterTextLabel.textColor;
        self.originalPosterTextLabel.textColor = [UIColor whiteColor];
    } else if (self.oldOriginalPosterTextColor) {
        self.originalPosterTextLabel.textColor = self.oldOriginalPosterTextColor;
        self.oldOriginalPosterTextColor = nil;
    }
    [self.unreadCountBadgeView setNeedsDisplay];
    [self.accessoryView setNeedsDisplay];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    if (selected) {
        self.oldOriginalPosterTextColor = self.originalPosterTextLabel.textColor;
        self.originalPosterTextLabel.textColor = [UIColor whiteColor];
    } else if (self.oldOriginalPosterTextColor) {
        self.originalPosterTextLabel.textColor = self.oldOriginalPosterTextColor;
        self.oldOriginalPosterTextColor = nil;
    }
    [self.unreadCountBadgeView setNeedsDisplay];
    [self.accessoryView setNeedsDisplay];
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

#pragma mark - UIAccessibility

- (NSString *)accessibilityLabel
{
    NSMutableArray *parts = [NSMutableArray new];
    [parts addObject:self.textLabel.accessibilityLabel];
    if (!self.stickyImageView.hidden) {
        [parts addObject:@"sticky"];
    }
    if (self.closed) {
        [parts addObject:@"closed"];
    }
    if (self.rating >= 1) {
        [parts addObject:[NSString stringWithFormat:@"rated %.1f", self.rating]];
    }
    [parts addObject:self.detailTextLabel.accessibilityLabel];
    [parts addObject:self.originalPosterTextLabel.accessibilityLabel];
    return [parts componentsJoinedByString:@", "];
}

- (NSString *)accessibilityValue
{
    if (!self.showsUnread) return @"Thread unread";
    NSInteger unread = [self.unreadCountBadgeView.badgeText integerValue];
    return [NSString stringWithFormat:@"%d unread post%@", unread, unread == 1 ? @"" : @"s"];
}

@end
