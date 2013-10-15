//  AwfulTabBarButton.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTabBarButton.h"

@implementation AwfulTabBarButton

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.titleLabel.font = [UIFont systemFontOfSize:11];
    [self setTitleColor:[UIColor colorWithWhite:0.541 alpha:1] forState:UIControlStateNormal];
    [self setTitleColor:self.tintColor forState:UIControlStateSelected];
    return self;
}

- (void)setImage:(UIImage *)image
{
    if (_image == image) return;
    _image = image;
    [self updateImages];
}

- (void)updateImages
{
    if (!self.image) {
        [self setImage:nil forState:UIControlStateNormal];
        [self setImage:nil forState:UIControlStateSelected];
        return;
    }
    
    CGRect all = (CGRect){ .size = self.image.size };
    UIGraphicsBeginImageContextWithOptions(self.image.size, NO, self.image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, CGRectGetHeight(all));
    CGContextScaleCTM(context, 1, -1);
    CGContextClipToMask(context, all, self.image.CGImage);
    
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, [self titleColorForState:UIControlStateNormal].CGColor);
    CGContextFillRect(context, all);
    UIImage *normal = UIGraphicsGetImageFromCurrentImageContext();
    CGContextRestoreGState(context);
    
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, self.tintColor.CGColor);
    CGContextFillRect(context, all);
    UIImage *selected = UIGraphicsGetImageFromCurrentImageContext();
    CGContextRestoreGState(context);
    
    UIGraphicsEndImageContext();
    
    [self setImage:normal forState:UIControlStateNormal];
    [self setImage:selected forState:UIControlStateSelected];
}

- (void)tintColorDidChange
{
    [self updateImages];
    [self setTitleColor:self.tintColor forState:UIControlStateSelected];
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect
{
    if (self.currentTitle.length == 0) {
        return CGRectZero;
    } else {
        [self.titleLabel sizeToFit];
        CGRect titleRect = self.titleLabel.bounds;
        titleRect.origin.x = CGRectGetMidX(contentRect) - CGRectGetWidth(titleRect) / 2;
        titleRect.origin.y = CGRectGetMaxY(contentRect) - CGRectGetHeight(titleRect);
        return titleRect;
    }
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect
{
    CGRect imageRect = [super imageRectForContentRect:contentRect];
    imageRect.origin.x = CGRectGetMidX(contentRect) - CGRectGetWidth(imageRect) / 2;
    return imageRect;
}

@end
