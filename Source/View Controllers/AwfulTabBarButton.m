//  AwfulTabBarButton.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTabBarButton.h"

@interface AwfulTabBarButton ()

@property (strong, nonatomic) UIImage *image;

@end

@implementation AwfulTabBarButton

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
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.541 alpha:1].CGColor);
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
}

@end
