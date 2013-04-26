//
//  AwfulIconActionCell.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulIconActionCell.h"

@interface AwfulIconActionCell ()

@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIImageView *imageView;

@end


@implementation AwfulIconActionCell

- (NSString *)title
{
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

- (void)setIcon:(UIImage *)icon
{
    if (_icon == icon) return;
    _icon = icon;
    [self updateImage];
}

- (void)setTintColor:(UIColor *)tintColor
{
    if (_tintColor == tintColor) return;
    _tintColor = tintColor;
    [self updateImage];
}

- (void)updateImage
{
    if (!self.tintColor) {
        self.imageView.image = nil;
        self.imageView.highlightedImage = nil;
        return;
    }
    
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:(CGRect){ .size = imageSize }
                                                     cornerRadius:10];
    path.lineWidth = 4;
    [path addClip];
    
    CGFloat hue, saturation, brightness, alpha;
    [self.tintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    brightness *= 0.8;
    UIColor *darkerColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness
                                           alpha:alpha];
    NSArray *colors = @[ (id)self.tintColor.CGColor, (id)darkerColor.CGColor ];
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace(darkerColor.CGColor),
                                                        (__bridge CFArrayRef)(colors), NULL);
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0, imageSize.height),
                                0);
    CGGradientRelease(gradient), gradient = NULL;
    
    [self.tintColor set];
    [path stroke];
    
    if (self.icon) {
        CGRect rect = (CGRect){ .size = self.icon.size };
        rect.origin.x = (imageSize.width - CGRectGetWidth(rect)) / 2;
        rect.origin.y = (imageSize.height - CGRectGetHeight(rect)) / 2;
        [self.icon drawInRect:rect];
    }
    
    self.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    
    [[UIColor colorWithWhite:0 alpha:0.3] set];
    [path fill];
    self.imageView.highlightedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
}

const CGSize imageSize = {56, 56};

#pragma mark - PSUICollectionViewCell

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.imageView.highlighted = highlighted;
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.titleLabel = [UILabel new];
    self.titleLabel.backgroundColor = nil;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.shadowColor = [UIColor blackColor];
    self.titleLabel.shadowOffset = CGSizeMake(0, 1);
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.titleLabel];
    self.imageView = [UIImageView new];
    [self.contentView addSubview:self.imageView];
    return self;
}

- (void)layoutSubviews
{
    const CGFloat imageWidth = 56;
    CGRect imageFrame, titleFrame;
    CGRectDivide(self.contentView.bounds, &imageFrame, &titleFrame, imageWidth, CGRectMinYEdge);
    imageFrame.origin.x += (CGRectGetWidth(imageFrame) - imageWidth) / 2;
    imageFrame.size.width = imageWidth;
    self.imageView.frame = imageFrame;
    self.titleLabel.frame = titleFrame;
    [self.titleLabel sizeToFit];
    titleFrame.size.height = CGRectGetHeight(self.titleLabel.frame);
    self.titleLabel.frame = titleFrame;
}

@end
