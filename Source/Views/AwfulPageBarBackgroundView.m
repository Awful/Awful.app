//
//  AwfulPageBarBackgroundView.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-08.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPageBarBackgroundView.h"

@implementation AwfulPageBarBackgroundView

- (void)drawRect:(CGRect)rect
{
    // Only draw where we're asked.
    [[UIBezierPath bezierPathWithRect:rect] addClip];
    
    // 1pt tall black line along top border.
    [[UIColor blackColor] setFill];
    CGRect thinWideLine = CGRectMake(0, 0, CGRectGetWidth(self.bounds), 1);
    [[UIBezierPath bezierPathWithRect:thinWideLine] fill];
    
    // On retina, a 1pt tall two-tone grey line below the top border.
    // Non-retina, it's just a grey line.
    if (self.contentScaleFactor > 1) {
        thinWideLine.size.height = 0.5;
        [[UIColor colorWithHue:0.333 saturation:0.009 brightness:0.439 alpha:1] setFill];
        [[UIBezierPath bezierPathWithRect:CGRectOffset(thinWideLine, 0, 1)] fill];
        [[UIColor colorWithHue:0.667 saturation:0.012 brightness:0.329 alpha:1] setFill];
        [[UIBezierPath bezierPathWithRect:CGRectOffset(thinWideLine, 0, 1.5)] fill];
    } else {
        [[UIColor colorWithHue:0.333 saturation:0.009 brightness:0.439 alpha:1] setFill];
        [[UIBezierPath bezierPathWithRect:CGRectOffset(thinWideLine, 0, 1)] fill];
    }
    
    // Grey-to-blackish gradient from top border to bottom.
    UIColor *start = [UIColor colorWithWhite:0.271 alpha:1];
    UIColor *end = [UIColor colorWithHue:0.333 saturation:0.029 brightness:0.133 alpha:1];
    CFArrayRef gradientColors = (__bridge CFArrayRef)@[ (id)start.CGColor, (id)end.CGColor ];
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace(start.CGColor),
                                                        gradientColors, NULL);
    CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(), gradient, CGPointMake(0, 2),
                                CGPointMake(0, CGRectGetHeight(self.bounds)), 0);
    CGGradientRelease(gradient), gradient = NULL;
}

@end
