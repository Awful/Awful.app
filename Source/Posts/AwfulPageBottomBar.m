//
//  AwfulPageBottomBar.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPageBottomBar.h"

@implementation AwfulPageBottomBar

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UIImage *previousPage = [UIImage imageNamed:@"arrowleft.png"];
    previousPage.accessibilityLabel = @"Previous page";
    UIImage *nextPage = [UIImage imageNamed:@"arrowright.png"];
    nextPage.accessibilityLabel = @"Next page";
    UISegmentedControl *backForwardControl = [[UISegmentedControl alloc]
                                              initWithItems:@[ previousPage, nextPage ]];
    [self addSubview:backForwardControl];
    _backForwardControl = backForwardControl;
    
    UIButton *jumpToPage = [UIButton buttonWithType:UIButtonTypeCustom];
    jumpToPage.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    jumpToPage.accessibilityHint = @"Jumps to a page";
    [self addSubview:jumpToPage];
    _jumpToPageButton = jumpToPage;
    
    UIImage *action = [UIImage imageNamed:@"action.png"];
    action.accessibilityLabel = @"Thread actions";
    UIImage *fontSize = [UIImage imageNamed:@"font-size.png"];
    fontSize.accessibilityLabel = @"Adjust style";
    UISegmentedControl *actionsFontSize = [[UISegmentedControl alloc]
                                           initWithItems:@[ action, fontSize ]];
    [self addSubview:actionsFontSize];
    _actionsFontSizeControl = actionsFontSize;
    
    return self;
}

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

- (void)layoutSubviews
{
    static const CGFloat horizontalMargin = 7;
    static const CGFloat segWidth = 85;
    static const CGFloat butWidth = 110;
    static const CGFloat itemHeight = 29;
    static const CGFloat topOffset = 1;
    
    self.backForwardControl.frame = CGRectMake(horizontalMargin, 0, segWidth, itemHeight);
    self.backForwardControl.center = CGPointMake(self.backForwardControl.center.x,
                                                 CGRectGetMidY(self.bounds) + topOffset);
    self.backForwardControl.frame = CGRectIntegral(self.backForwardControl.frame);
    
    self.jumpToPageButton.bounds = CGRectMake(0, 0, butWidth, itemHeight);
    self.jumpToPageButton.center = CGPointMake(CGRectGetMidX(self.bounds),
                                               CGRectGetMidY(self.bounds) + topOffset);
    self.jumpToPageButton.frame = CGRectIntegral(self.jumpToPageButton.frame);
    
    self.actionsFontSizeControl.frame = CGRectMake(CGRectGetMaxX(self.bounds) - horizontalMargin -
                                                   segWidth, 0, segWidth, itemHeight);
    self.actionsFontSizeControl.center = CGPointMake(self.actionsFontSizeControl.center.x,
                                                     CGRectGetMidY(self.bounds) + topOffset);
    self.actionsFontSizeControl.frame = CGRectIntegral(self.actionsFontSizeControl.frame);
}

#pragma mark - NSObject

+ (void)initialize
{
    if (self != [AwfulPageBottomBar class]) return;
    UISegmentedControl *seg = [UISegmentedControl appearanceWhenContainedIn:
                               [AwfulPageBottomBar class], nil];
    UIImage *buttonBack = [[UIImage imageNamed:@"pagebar-button.png"]
                           resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [seg setBackgroundImage:buttonBack
                   forState:UIControlStateNormal
                 barMetrics:UIBarMetricsDefault];
    UIImage *buttonSelected = [[UIImage imageNamed:@"pagebar-button-selected.png"]
                               resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [seg setBackgroundImage:buttonSelected
                   forState:UIControlStateHighlighted
                 barMetrics:UIBarMetricsDefault];
    [seg setDividerImage:[UIImage imageNamed:@"pagebar-segmented-divider.png"]
     forLeftSegmentState:UIControlStateNormal
       rightSegmentState:UIControlStateNormal
              barMetrics:UIBarMetricsDefault];
    
    UIButton *button = [UIButton appearanceWhenContainedIn:[AwfulPageBottomBar class], nil];
    [button setBackgroundImage:buttonBack forState:UIControlStateNormal];
    [button setBackgroundImage:buttonSelected forState:UIControlStateHighlighted];
}

@end
