//
//  AwfulNavigationBar.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulNavigationBar.h"

@implementation AwfulNavigationBar

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    [longPress addTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    return self;
}

- (void)longPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (self.leftButtonLongTapAction) {
        return self.leftButtonLongTapAction();
    }
    if (!self.backItem) return;
    UINavigationController *nav = self.delegate;
    if (![nav isKindOfClass:[UINavigationController class]]) return;
    UIView *leftmost;
    for (UIView *subview in self.subviews) {
        if (leftmost && CGRectGetMinX(leftmost.frame) < CGRectGetMinX(subview.frame)) continue;
        if (subview.frame.size.width > self.frame.size.width / 2) continue;
        leftmost = subview;
    }
    CGRect backFrame = leftmost ? leftmost.frame : CGRectMake(5, 0, 100, 40);
    if (CGRectContainsPoint(backFrame, [recognizer locationInView:self])) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

- (void)drawRect:(CGRect)rect
{
    // Only redraw what we're asked for.
    [[UIBezierPath bezierPathWithRect:rect] addClip];
    
    // 1pt tall bright blue line along the top. This appears just below the status bar.
    [[UIColor colorWithHue:0.550 saturation:0.888 brightness:0.773 alpha:1] set];
    [[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, CGRectGetWidth(self.bounds), 1)] fill];
    
    // Dark blue to darker blue gradient from top to bottom.
    UIColor *start = [UIColor colorWithHue:0.549 saturation:0.893 brightness:0.659 alpha:1];
    UIColor *end = [UIColor colorWithHue:0.564 saturation:0.921 brightness:0.592 alpha:1];
    CFArrayRef gradientColors = (__bridge CFArrayRef)@[ (id)start.CGColor, (id)end.CGColor ];
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace(start.CGColor),
                                                        gradientColors, NULL);
    CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(), gradient, CGPointMake(0, 1),
                                CGPointMake(0, CGRectGetHeight(self.bounds) - 1), 0);
    CGGradientRelease(gradient), gradient = NULL;
    
    // 1pt tall darkdark blue line along the bottom. This appears just above the content of the
    // navigation controller.
    [[UIColor colorWithHue:0.562 saturation:0.935 brightness:0.486 alpha:1] set];
    [[UIBezierPath bezierPathWithRect:CGRectMake(0, CGRectGetHeight(self.bounds) - 1,
                                                 CGRectGetWidth(self.bounds), 1)] fill];
}

#pragma mark - NSObject

+ (void)initialize
{
    if (self != [AwfulNavigationBar class]) return;
    AwfulNavigationBar *navBar = [AwfulNavigationBar appearance];
    [navBar setTitleTextAttributes:@{
        UITextAttributeTextColor : [UIColor whiteColor],
        UITextAttributeTextShadowColor : [UIColor colorWithWhite:0 alpha:0.5],
    }];
    
    UIBarButtonItem *navBarItem = [UIBarButtonItem appearanceWhenContainedIn:
                                   [AwfulNavigationBar class], nil];
    UIImage *navBarButton = [UIImage imageNamed:@"navbar-button.png"];
    [navBarItem setBackgroundImage:navBarButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsDefault];
    UIImage *navBarLandscapeButton = [[UIImage imageNamed:@"navbar-button-landscape.png"]
                                      resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)];
    [navBarItem setBackgroundImage:navBarLandscapeButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsLandscapePhone];
    UIImage *backButton = [[UIImage imageNamed:@"navbar-back.png"]
                           resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:backButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsDefault];
    UIImage *landscapeBackButton = [[UIImage imageNamed:@"navbar-back-landscape.png"]
                                    resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:landscapeBackButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsLandscapePhone];
}

@end
