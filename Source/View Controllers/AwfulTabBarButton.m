//  AwfulTabBarButton.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTabBarButton.h"

@implementation AwfulTabBarButton

- (void)setImage:(UIImage *)image
{
    CGRect all = (CGRect){ .size = image.size };
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, CGRectGetHeight(all));
    CGContextScaleCTM(context, 1, -1);
    CGContextClipToMask(context, all, image.CGImage);
    
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

@end
