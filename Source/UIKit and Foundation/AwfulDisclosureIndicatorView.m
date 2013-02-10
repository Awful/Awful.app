//
//  AwfulDisclosureIndicatorView.m
//  Awful
//
//  Created by Nolan Waite on 2012-12-04.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulDisclosureIndicatorView.h"

@interface AwfulDisclosureIndicatorView ()

@property (weak, nonatomic) UITableViewCell *cell;

@end


@implementation AwfulDisclosureIndicatorView

- (id)init
{
    return [self initWithFrame:CGRectMake(0, 0, 10, 13)];
}

- (void)setColor:(UIColor *)color
{
    if (_color == color) return;
    _color = color;
    [self setNeedsDisplay];
}

- (void)setHighlightedColor:(UIColor *)highlightedColor
{
    if (_highlightedColor == highlightedColor) return;
    _highlightedColor = highlightedColor;
    [self setNeedsDisplay];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _color = [UIColor grayColor];
    _highlightedColor = [UIColor whiteColor];
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    UIView *cell = newSuperview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = cell.superview;
    }
    self.cell = (id)cell;
}

- (void)drawRect:(CGRect)rect
{
    // http://stackoverflow.com/a/1997147
    CGPoint tip = CGPointMake(CGRectGetMaxX(self.bounds) - 3, CGRectGetMidY(self.bounds));
    CGFloat radius = 4.5;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextMoveToPoint(context, tip.x - radius, tip.y - radius);
    CGContextAddLineToPoint(context, tip.x, tip.y);
    CGContextAddLineToPoint(context, tip.x - radius, tip.y + radius);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextSetLineJoin(context, kCGLineJoinMiter);
    CGContextSetLineWidth(context, 3);
    UIColor *color = self.color;
    if (self.cell.selected || self.cell.highlighted) color = self.highlightedColor;
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextStrokePath(context);
}

@end
