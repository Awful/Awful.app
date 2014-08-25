//  AwfulIconActionCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionCell.h"

@interface AwfulIconActionCell ()

@property (strong, nonatomic) UIImageView *iconImageView;

@property (strong, nonatomic) UILabel *titleLabel;

@end

@implementation AwfulIconActionCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.titleLabel = [UILabel new];
    self.titleLabel.backgroundColor = nil;
    self.titleLabel.font = [UIFont systemFontOfSize:12];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.titleLabel];
    
    self.iconImageView = [UIImageView new];
    self.iconImageView.contentMode = UIViewContentModeCenter;
    [self.contentView addSubview:self.iconImageView];
    
    return self;
}

- (void)setTintColor:(UIColor *)tintColor
{
    if (_tintColor == tintColor) return;
    _tintColor = tintColor;
    if (!self.highlighted) {
        self.iconImageView.tintColor = tintColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (highlighted) {
        self.iconImageView.tintColor = [UIColor whiteColor];
    } else {
        self.iconImageView.tintColor = self.tintColor;
    }
}

- (void)layoutSubviews
{
    CGRect iconFrame;
    CGRect titleFrame;
    CGRectDivide(self.contentView.bounds, &iconFrame, &titleFrame, ImageSize.height, CGRectMinYEdge);
    
    iconFrame.origin.x += (CGRectGetWidth(iconFrame) - ImageSize.width) / 2;
    iconFrame.size.width = ImageSize.width;
    self.iconImageView.frame = iconFrame;
    
    self.titleLabel.frame = titleFrame;
    [self.titleLabel sizeToFit];
    titleFrame.size.height = CGRectGetHeight(self.titleLabel.frame);
    self.titleLabel.frame = titleFrame;
}

static const CGSize ImageSize = { 56, 56 };

@end
