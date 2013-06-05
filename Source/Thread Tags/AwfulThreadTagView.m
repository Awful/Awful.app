//
//  AwfulThreadTagView.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-22.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulThreadTagView.h"

@interface AwfulThreadTagView ()

@property (nonatomic) UIImageView *tagImageView;
@property (nonatomic) UIImageView *secondaryTagImageView;

@end


@implementation AwfulThreadTagView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.tagImageView = [UIImageView new];
    [self addSubview:self.tagImageView];
    return self;
}

- (UIImage *)tagImage
{
    return self.tagImageView.image;
}

- (void)setTagImage:(UIImage *)tagImage
{
    self.tagImageView.image = tagImage;
}

- (void)setTagBorderColor:(UIColor *)borderColor width:(CGFloat)width
{
    if (borderColor && width > 0) {
        self.tagImageView.layer.borderColor = borderColor.CGColor;
        self.tagImageView.layer.borderWidth = width;
    } else {
        self.tagImageView.layer.borderColor = nil;
        self.tagImageView.layer.borderWidth = 0;
    }
}

- (UIImage *)secondaryTagImage
{
    return self.secondaryTagImageView.image;
}

- (void)setSecondaryTagImage:(UIImage *)secondaryTagImage
{
    if (secondaryTagImage) {
        if (!self.secondaryTagImageView) {
            self.secondaryTagImageView = [UIImageView new];
            [self addSubview:self.secondaryTagImageView];
            [self setNeedsLayout];
        }
        self.secondaryTagImageView.image = secondaryTagImage;
    } else {
        [self.secondaryTagImageView removeFromSuperview];
        self.secondaryTagImageView = nil;
    }
}

- (void)layoutSubviews
{
    CGRect tagFrame = (CGRect){ .size = self.bounds.size };
    self.tagImageView.frame = tagFrame;
    self.secondaryTagImageView.frame = (CGRect){
        .origin = {-1, -1},
        .size = { CGRectGetWidth(tagFrame) / 2, CGRectGetHeight(tagFrame) / 2 },
    };
}

@end
