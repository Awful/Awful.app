//
//  AwfulImageCollectionViewCell.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulImageCollectionViewCell.h"

@interface AwfulImageCollectionViewCell ()

@property (nonatomic) UIImageView *imageView;
@property (nonatomic) UIImageView *secondaryIconImageView;

@end


@implementation AwfulImageCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.imageView = [UIImageView new];
    [self.contentView addSubview:self.imageView];
    self.secondaryIconImageView = [UIImageView new];
    self.secondaryIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.secondaryIconImageView];
    return self;
}

- (UIImage *)secondaryIcon
{
    return self.secondaryIconImageView.image;
}

- (void)setSecondaryIcon:(UIImage *)secondaryIcon
{
    self.secondaryIconImageView.image = secondaryIcon;
    self.secondaryIconImageView.hidden = !secondaryIcon;
    if (secondaryIcon) [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGRect imageFrame = CGRectInset((CGRect){ .size = self.frame.size }, 2, 2);
    self.imageView.frame = imageFrame;
    self.secondaryIconImageView.frame = (CGRect){
        .origin = imageFrame.origin,
        .size.width = CGRectGetWidth(imageFrame) / 2,
        .size.height = CGRectGetHeight(imageFrame) / 2,
    };
}

@end
