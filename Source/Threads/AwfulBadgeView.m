//
//  AwfulBadgeView.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-02.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBadgeView.h"
#import "AwfulTheme.h"

@interface AwfulBadgeView ()

@property (weak, nonatomic) UITableViewCell *cell;

@property (readonly, nonatomic) UIFont *font;

@end

@implementation AwfulBadgeView

- (id)initWithCell:(UITableViewCell *)cell
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _cell = cell;
        _badgeColor = [UIColor colorWithRed:0.169 green:0.408 blue:0.588 alpha:1];
        _highlightedBadgeColor = [UIColor whiteColor];
        _offBadgeColor = [UIColor colorWithRed:0.435 green:0.659 blue:0.769 alpha:1];
        _on = YES;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.layer.masksToBounds = YES;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Technique via DDBadgeViewCell by Ching-Lan 'digdog' HUANG.
    // https://github.com/digdog/DDBadgeViewCell
    UIColor *badgeColor = self.on ? self.badgeColor : self.offBadgeColor;
    if (self.cell.highlighted || self.cell.selected) {
        badgeColor = self.highlightedBadgeColor;
    }
    
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, badgeColor.CGColor);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddArc(path, NULL,
                 self.bounds.origin.x + self.bounds.size.width - self.bounds.size.height / 2,
                 self.bounds.origin.y + self.bounds.size.height / 2,
                 self.bounds.size.height / 2, M_PI / 2, M_PI * 3 / 2, YES);
    CGPathAddArc(path, NULL,
                 self.bounds.origin.x + self.bounds.size.height / 2,
                 self.bounds.origin.y + self.bounds.size.height / 2,
                 self.bounds.size.height / 2, M_PI * 3 / 2, M_PI / 2, YES);
    CGContextAddPath(context, path);
    CGContextDrawPath(context, kCGPathFill);
    CGPathRelease(path);
    CGContextRestoreGState(context);
    
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, kCGBlendModeClear);
    [self.badgeText drawInRect:CGRectInset(self.bounds, 7, 2) withFont:self.font];
    CGContextRestoreGState(context);
}

- (void)sizeToFit
{
    CGSize textSize = [self.badgeText sizeWithFont:self.font];
    CGRect bounds = self.bounds;
    bounds.size = CGSizeMake(textSize.width + 14, textSize.height + 4);
    self.bounds = bounds;
}

- (UIFont *)font
{
    return [UIFont boldSystemFontOfSize:13];
}

- (void)setBadgeText:(NSString *)badgeText
{
    if (_badgeText == badgeText) return;
    _badgeText = [badgeText copy];
    [self setNeedsDisplay];
}

- (void)setBadgeColor:(UIColor *)badgeColor
{
    if (_badgeColor == badgeColor) return;
    _badgeColor = badgeColor;
    [self setNeedsDisplay];
}

- (void)setHighlightedBadgeColor:(UIColor *)highlightedBadgeColor
{
    if (_highlightedBadgeColor == highlightedBadgeColor) return;
    _highlightedBadgeColor = highlightedBadgeColor;
    [self setNeedsDisplay];
}

- (void)setOffBadgeColor:(UIColor *)offBadgeColor
{
    if (_offBadgeColor == offBadgeColor) return;
    _offBadgeColor = offBadgeColor;
    [self setNeedsDisplay];
}

- (void)setOn:(BOOL)on
{
    if (_on == on) return;
    _on = on;
    [self setNeedsDisplay];
}

@end
