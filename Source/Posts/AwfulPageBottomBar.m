//
//  AwfulPageBottomBar.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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
