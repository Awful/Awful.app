//  AwfulHoleyDimmingView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHoleyDimmingView.h"

@implementation AwfulHoleyDimmingView
{
    CAShapeLayer *_mask;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    self.opaque = NO;
    
    self.dimRect = CGRectInfinite;
    
    _mask = [CAShapeLayer new];
    _mask.fillColor = [UIColor blackColor].CGColor;
    _mask.fillRule = kCAFillRuleEvenOdd;
    self.layer.mask = _mask;
    
    return self;
}

- (void)setDimRect:(CGRect)dimmingRect
{
    _dimRect = dimmingRect;
    [self setNeedsLayout];
}

- (void)setHole:(CGRect)hole
{
    _hole = hole;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    _mask.frame = bounds;
    
    CGRect dimmingRect = self.dimRect;
    if (CGRectIsInfinite(dimmingRect)) {
        dimmingRect = bounds;
    }
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:dimmingRect];
    
    CGRect hole = self.hole;
    if (!CGRectIsEmpty(hole)) {
        UIBezierPath *holePath = [UIBezierPath bezierPathWithRect:hole];
        [path appendPath:holePath];
    }
    
    _mask.path = path.CGPath;
}

@end
