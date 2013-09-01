//  AwfulBadgeView.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBadgeView.h"

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
        _textColor = [UIColor whiteColor];
        _highlightedTextColor = [UIColor blackColor];
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
    UIColor *badgeColor = self.on ? self.badgeColor : self.offBadgeColor;
    UIColor *textColor = self.textColor;
    if (self.cell.highlighted || self.cell.selected) {
        badgeColor = self.highlightedBadgeColor;
        textColor = self.highlightedTextColor;
    }
    CGContextSetFillColorWithColor(context, badgeColor.CGColor);
    CGContextAddArc(context,
                    self.bounds.origin.x + self.bounds.size.width - self.bounds.size.height / 2,
                    self.bounds.origin.y + self.bounds.size.height / 2,
                    self.bounds.size.height / 2, M_PI / 2, M_PI * 3 / 2, 1);
    CGContextAddArc(context,
                    self.bounds.origin.x + self.bounds.size.height / 2,
                    self.bounds.origin.y + self.bounds.size.height / 2,
                    self.bounds.size.height / 2, M_PI * 3 / 2, M_PI / 2, 1);
    CGContextDrawPath(context, kCGPathFill);
    CGContextSetFillColorWithColor(context, textColor.CGColor);
    [self.badgeText drawInRect:CGRectInset(self.bounds, 7, 2) withAttributes:@{ NSFontAttributeName: self.font }];
}

- (void)sizeToFit
{
    CGRect textRect = [self.badgeText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                   options:0
                                                attributes:@{ NSFontAttributeName: self.font }
                                                   context:nil];
    CGRect bounds = self.bounds;
    bounds.size = CGSizeMake(CGRectGetWidth(textRect) + 14, CGRectGetHeight(textRect) + 4);
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

- (void)setTextColor:(UIColor *)textColor
{
    if (_textColor == textColor) return;
    _textColor = textColor;
    [self setNeedsDisplay];
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor
{
    if (_highlightedTextColor == highlightedTextColor) return;
    _highlightedTextColor = highlightedTextColor;
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
