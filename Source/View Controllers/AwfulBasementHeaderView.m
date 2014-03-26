//  AwfulBasementHeaderView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBasementHeaderView.h"

@implementation AwfulBasementHeaderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _bottomOffset = 12;
    
    _avatarImageView = [UIImageView new];
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_avatarImageView];
    
    _usernameLabel = [UILabel new];
    _usernameLabel.font = [UIFont boldSystemFontOfSize:17];
    [self addSubview:_usernameLabel];
    
    return self;
}

- (void)setBottomOffset:(CGFloat)bottomOffset
{
    _bottomOffset = bottomOffset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    
    const CGFloat usernameInset = 50;
    CGRect usernameFrame = CGRectMake(usernameInset, 0, CGRectGetWidth(bounds) - usernameInset, 0);
    _usernameLabel.frame = usernameFrame;
    [_usernameLabel sizeToFit];
    usernameFrame.size.height = CGRectGetHeight(_usernameLabel.frame);
    usernameFrame.origin.y = CGRectGetMaxY(bounds) - CGRectGetHeight(usernameFrame) - self.bottomOffset;
    _usernameLabel.frame = usernameFrame;
    
    _avatarImageView.bounds = CGRectMake(0, 0, 28, 24);
    _avatarImageView.center = CGPointMake(25, _usernameLabel.center.y);
}

@end
