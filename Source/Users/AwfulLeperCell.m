//  AwfulLeperCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLeperCell.h"

@interface AwfulLeperCell ()

@property (weak, nonatomic) UILabel *reasonLabel;

@end


@implementation AwfulLeperCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier])) return nil;
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    self.usernameLabel.font = [UIFont boldSystemFontOfSize:15];
    self.usernameLabel.backgroundColor = [UIColor clearColor];
    self.dateAndModLabel.font = [UIFont systemFontOfSize:13];
    self.dateAndModLabel.backgroundColor = [UIColor clearColor];
    
    UILabel *reasonLabel = [UILabel new];
    reasonLabel.numberOfLines = 0;
    reasonLabel.font = [UIFont systemFontOfSize:15];
    reasonLabel.backgroundColor = [UIColor clearColor];
    reasonLabel.highlightedTextColor = self.usernameLabel.highlightedTextColor;
    [self.contentView addSubview:reasonLabel];
    _reasonLabel = reasonLabel;
    
    return self;
}

- (UILabel *)usernameLabel
{
    return self.textLabel;
}

- (UILabel *)dateAndModLabel
{
    return self.detailTextLabel;
}

- (void)setDisclosureIndicator:(AwfulDisclosureIndicatorView *)disclosureIndicator
{
    if ([_disclosureIndicator isEqual:disclosureIndicator]) return;
    [_disclosureIndicator removeFromSuperview];
    _disclosureIndicator = disclosureIndicator;
    [self.contentView addSubview:disclosureIndicator];
}

+ (CGFloat)rowHeightWithBanReason:(NSString *)banReason width:(CGFloat)width
{
    const UIEdgeInsets reasonInsets = (UIEdgeInsets){
        .left = 10, .right = 30,
        .top = 63, .bottom = 10,
    };
    width -= reasonInsets.left + reasonInsets.right;
    CGSize reasonLabelSize = [banReason sizeWithFont:[UIFont systemFontOfSize:15]
                                   constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
                                       lineBreakMode:NSLineBreakByWordWrapping];
    return reasonLabelSize.height + reasonInsets.top + reasonInsets.bottom;
}

#pragma mark - UITableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

#pragma mark - UIView

- (void)layoutSubviews
{
    const UIEdgeInsets cellMargin = (UIEdgeInsets){
        .left = 10, .right = 10,
        .top = 5, .bottom = 10,
    };
    
    // TODO maybe bump the image view up a couple points
    self.imageView.frame = CGRectMake(cellMargin.left, cellMargin.top, 44, 44);
    const CGFloat imageViewRightMargin = 10;
    const CGFloat imageViewBottomMargin = 12;
    
    CGRect usernameFrame = (CGRect){
        .origin = { CGRectGetMaxX(self.imageView.frame) + imageViewRightMargin, 9 },
        .size.height = self.usernameLabel.font.lineHeight,
    };
    usernameFrame.size.width = (CGRectGetWidth(self.contentView.frame) -
                                CGRectGetMinX(usernameFrame) - cellMargin.right);
    self.usernameLabel.frame = usernameFrame;
    
    self.dateAndModLabel.frame = CGRectOffset(usernameFrame, 0, CGRectGetHeight(usernameFrame));
    
    const CGFloat reasonLabelRightMargin = 32;
    CGRect reasonFrame = (CGRect){
        .origin.x = cellMargin.left,
        .origin.y = CGRectGetMaxY(self.imageView.frame) + imageViewBottomMargin,
        .size.width = (CGRectGetWidth(self.contentView.frame) - cellMargin.left -
                       reasonLabelRightMargin),
    };
    CGFloat cellHeight = [[self class] rowHeightWithBanReason:self.reasonLabel.text
                                                        width:CGRectGetWidth(self.contentView.frame)];
    reasonFrame.size.height = cellHeight - CGRectGetMinY(reasonFrame) - cellMargin.bottom;
    self.reasonLabel.frame = reasonFrame;
    
    if (self.disclosureIndicator) {
        const CGFloat disclosureCenterXFromRight = 15;
        self.disclosureIndicator.center = (CGPoint){
            .x = CGRectGetWidth(self.contentView.frame) - disclosureCenterXFromRight,
            .y = CGRectGetMidY(reasonFrame),
        };
        self.disclosureIndicator.frame = CGRectIntegral(self.disclosureIndicator.frame);
    }
}

@end
