//  AwfulPopoverBackgroundView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPopoverBackgroundView.h"
#import "AwfulTheme.h"

@implementation AwfulPopoverBackgroundView
{
    CAShapeLayer *_maskLayer;
}

@synthesize arrowOffset = _arrowOffset;
@synthesize arrowDirection = _arrowDirection;
@synthesize theme = _theme;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _maskLayer = [CAShapeLayer new];
    _maskLayer.frame = (CGRect){ .size = frame.size };
    _maskLayer.fillColor = [UIColor blackColor].CGColor;
    self.layer.mask = _maskLayer;
    
    [self themeDidChange];
    
    return self;
}

- (AwfulTheme *)theme
{
    return _theme ?: [AwfulTheme currentTheme];
}

- (void)setTheme:(AwfulTheme *)theme
{
    _theme = theme;
    [self themeDidChange];
}

- (void)themeDidChange
{
    self.backgroundColor = self.theme[@"sheetBackgroundColor"];
}

+ (UIEdgeInsets)contentViewInsets
{
    return UIEdgeInsetsZero;
}

+ (CGFloat)arrowHeight
{
    return 13;
}

+ (CGFloat)arrowBase
{
    return 37;
}

- (void)setArrowOffset:(CGFloat)arrowOffset
{
    _arrowOffset = arrowOffset;
    [self setNeedsLayout];
}

- (void)setArrowDirection:(UIPopoverArrowDirection)arrowDirection
{
    _arrowDirection = arrowDirection;
    [self setNeedsLayout];
}

- (UIBezierPath *)arrowPathMaskInRect:(CGRect)container
{
    CGFloat base = [[self class] arrowBase];
    CGFloat height = [[self class] arrowHeight];
    UIBezierPath *path = [UIBezierPath new];
    [path moveToPoint:CGPointMake(0, height)];
    [path addCurveToPoint:CGPointMake(base / 2, 0)
            controlPoint1:CGPointMake(base * 0.35, height * 1.1)
            controlPoint2:CGPointMake(base * 0.35, 0)];
    [path addCurveToPoint:CGPointMake(base, height)
            controlPoint1:CGPointMake(base * 0.65, 0)
            controlPoint2:CGPointMake(base * 0.65, height * 1.1)];
    [path closePath];
    [path applyTransform:CGAffineTransformMakeTranslation(-base / 2, -height / 2)];
    
    UIPopoverArrowDirection direction = self.arrowDirection;
    [path applyTransform:RotationTransformForArrowDirection(direction)];
    CGFloat offset = self.arrowOffset;
    switch (direction) {
        default:
            [path applyTransform:CGAffineTransformMakeTranslation(CGRectGetMidX(container) + offset, height / 2 + CGRectGetMinY(container))];
            break;
            
        case UIPopoverArrowDirectionLeft:
        case UIPopoverArrowDirectionRight:
            [path applyTransform:CGAffineTransformMakeTranslation(height / 2 + CGRectGetMinX(container), CGRectGetMidY(container) + offset)];
            break;
    }
    return path;
}

static inline CGAffineTransform RotationTransformForArrowDirection(UIPopoverArrowDirection arrowDirection)
{
    switch (arrowDirection) {
        case UIPopoverArrowDirectionUp: return CGAffineTransformIdentity;
        case UIPopoverArrowDirectionLeft: return CGAffineTransformMakeRotation(-M_PI_2);
        case UIPopoverArrowDirectionRight: return CGAffineTransformMakeRotation(M_PI_2);
        default: return CGAffineTransformMakeRotation(M_PI);
    }
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    _maskLayer.frame = (CGRect){ .size = bounds.size };
    
    CGRect contentRect;
    CGRect arrowContainer;
    CGRectEdge arrowEdge = RectEdgeForArrowDirection(self.arrowDirection);
    CGRectDivide(bounds, &arrowContainer, &contentRect, [[self class] arrowHeight], arrowEdge);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:contentRect cornerRadius:11];
    [path appendPath:[self arrowPathMaskInRect:arrowContainer]];
    _maskLayer.path = path.CGPath;
}

static inline CGRectEdge RectEdgeForArrowDirection(UIPopoverArrowDirection arrowDirection)
{
    switch (arrowDirection) {
        case UIPopoverArrowDirectionUp: return CGRectMinYEdge; break;
        case UIPopoverArrowDirectionLeft: return CGRectMinXEdge; break;
        case UIPopoverArrowDirectionRight: return CGRectMaxXEdge; break;
        default: return CGRectMaxYEdge; break;
    }
}

@end
