//  AwfulPopoverBackgroundView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPopoverBackgroundView.h"
#import "AwfulTheme.h"

@implementation AwfulPopoverBackgroundView
{
    UIImageView *_backgroundImageView;
    UIImageView *_arrowImageView;
}

@synthesize arrowOffset = _arrowOffset;
@synthesize arrowDirection = _arrowDirection;

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    UIImage *backgroundImage = [[UIImage imageNamed:@"popover-background"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
    [self addSubview:_backgroundImageView];
    
    UIImage *arrowImage = [[UIImage imageNamed:@"popover-arrow"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _arrowImageView = [[UIImageView alloc] initWithImage:arrowImage];
    [self addSubview:_arrowImageView];
    
    self.tintColor = AwfulTheme.currentTheme[@"actionSheetBackgroundColor"];
    return self;
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

- (void)tintColorDidChange
{
    _backgroundImageView.tintColor = self.tintColor;
    _arrowImageView.tintColor = self.tintColor;
}

- (void)layoutSubviews
{
    CGRect arrowFrame;
    CGRect backgroundFrame;
    CGRectEdge arrowEdge;
    switch (self.arrowDirection) {
        case UIPopoverArrowDirectionUp: arrowEdge = CGRectMinYEdge; break;
        case UIPopoverArrowDirectionLeft: arrowEdge = CGRectMinXEdge; break;
        case UIPopoverArrowDirectionRight: arrowEdge = CGRectMaxXEdge; break;
        case UIPopoverArrowDirectionDown: arrowEdge = CGRectMaxYEdge; break;
        
        // We're at the mercy of UIPopoverController, so no point complaining about invalid arrow directions. Just make it work.
        default: arrowEdge = CGRectMaxYEdge; break;
    }
    
    CGFloat arrowHeight = self.class.arrowHeight;
    CGFloat arrowBase = self.class.arrowBase;
    CGRectDivide(self.bounds, &arrowFrame, &backgroundFrame, arrowHeight, arrowEdge);
    if (arrowEdge == CGRectMinYEdge || arrowEdge == CGRectMaxYEdge) {
        arrowFrame = CGRectInset(arrowFrame, (CGRectGetWidth(arrowFrame) - arrowBase) / 2, 0);
        arrowFrame = CGRectOffset(arrowFrame, self.arrowOffset, 0);
    } else {
        arrowFrame = CGRectInset(arrowFrame, 0, CGRectGetHeight(arrowFrame) - arrowBase);
        arrowFrame = CGRectOffset(arrowFrame, 0, self.arrowOffset);
    }
    _arrowImageView.frame = arrowFrame;
    _backgroundImageView.frame = backgroundFrame;
    
    switch (arrowEdge) {
        case CGRectMinYEdge: _arrowImageView.transform = CGAffineTransformMakeRotation(0); break;
        case CGRectMaxYEdge: _arrowImageView.transform = CGAffineTransformMakeRotation(M_PI); break;
        case CGRectMinXEdge: _arrowImageView.transform = CGAffineTransformMakeRotation(M_PI_2); break;
        case CGRectMaxXEdge: _arrowImageView.transform = CGAffineTransformMakeRotation(-M_PI_2); break;
    }
}

@end
