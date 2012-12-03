//
//  AwfulPageBar.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-18.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageBar.h"

@implementation AwfulPageBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleTopMargin);
        
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
        UIImage *reply = [UIImage imageNamed:@"compose.png"];
        reply.accessibilityLabel = @"Reply to thread";
        UISegmentedControl *actionsCompose = [[UISegmentedControl alloc]
                                              initWithItems:@[ action, reply ]];
        [self addSubview:actionsCompose];
        _actionsComposeControl = actionsCompose;
        
        [self configureAppearance];
    }
    return self;
}

- (void)configureAppearance
{
    UIImage *back = [[UIImage imageNamed:@"pagebar.png"]
                     resizableImageWithCapInsets:UIEdgeInsetsZero];
    self.backgroundColor = [UIColor colorWithPatternImage:back];
    
    UIImage *button = [[UIImage imageNamed:@"pagebar-button.png"]
                       resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    UIImage *selected = [[UIImage imageNamed:@"pagebar-button-selected.png"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    for (UISegmentedControl *seg in @[ self.backForwardControl, self.actionsComposeControl ]) {
        [seg setBackgroundImage:button
                       forState:UIControlStateNormal
                     barMetrics:UIBarMetricsDefault];
        [seg setBackgroundImage:selected
                       forState:UIControlStateHighlighted
                     barMetrics:UIBarMetricsDefault];
        [seg setDividerImage:[UIImage imageNamed:@"pagebar-segmented-divider.png"]
         forLeftSegmentState:UIControlStateNormal
           rightSegmentState:UIControlStateNormal
                  barMetrics:UIBarMetricsDefault];
    }
    [self.jumpToPageButton setBackgroundImage:button forState:UIControlStateNormal];
    [self.jumpToPageButton setBackgroundImage:selected forState:UIControlStateHighlighted];
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
    
    self.actionsComposeControl.frame = CGRectMake(CGRectGetMaxX(self.bounds) - horizontalMargin - segWidth, 0,
                                                  segWidth, itemHeight);
    self.actionsComposeControl.center = CGPointMake(self.actionsComposeControl.center.x,
                                                    CGRectGetMidY(self.bounds) + topOffset);
    self.actionsComposeControl.frame = CGRectIntegral(self.actionsComposeControl.frame);
}

@end
