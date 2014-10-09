//  SmilieCell.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieCell.h"

@interface SmilieCell ()

@property (strong, nonatomic) FLAnimatedImageView *imageView;

@end

@implementation SmilieCell

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 5;
        self.layer.shadowOpacity = 1;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowRadius = 0;
        self.layer.shadowColor = [UIColor lightGrayColor].CGColor;
    }
    return self;
}

- (FLAnimatedImageView *)imageView
{
    if (!_imageView) {
        _imageView = [FLAnimatedImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_imageView];
        
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_imageView
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1
                                       constant:0]];
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_imageView
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
    }
    return _imageView;
}

- (void)setNormalBackgroundColor:(UIColor *)normalBackgroundColor
{
    _normalBackgroundColor = normalBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    _selectedBackgroundColor = selectedBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateBackgroundColor];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateBackgroundColor];
}

- (void)updateBackgroundColor
{
    if (self.highlighted || self.selected) {
        self.contentView.backgroundColor = self.selectedBackgroundColor;
    } else {
        self.contentView.backgroundColor = self.normalBackgroundColor;
    }
}

@end
