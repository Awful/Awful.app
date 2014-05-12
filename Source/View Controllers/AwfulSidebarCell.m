//  AwfulSidebarCell.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSidebarCell.h"

@implementation AwfulSidebarCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.imageView.contentMode = UIViewContentModeCenter;
        _separatorView = [UIView new];
        [self.contentView addSubview:_separatorView];
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (UILabel *)badgeLabel
{
    if (!self.accessoryView) {
        self.accessoryView = [UILabel new];
    }
    return (UILabel *)self.accessoryView;
}

- (void)setBadgeLabel:(UILabel *)badgeLabel
{
    self.accessoryView = badgeLabel;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    
    static const CGFloat separatorHeight = 1;
    CGRect separatorFrame = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - separatorHeight,
                                       CGRectGetWidth(bounds), separatorHeight);
    _separatorView.frame = UIEdgeInsetsInsetRect(separatorFrame, self.separatorInset);
}

@end
