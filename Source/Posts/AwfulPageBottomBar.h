//  AwfulPageBottomBar.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageBarBackgroundView.h"

@interface AwfulPageBottomBar : AwfulPageBarBackgroundView

@property (readonly, weak, nonatomic) UISegmentedControl *backForwardControl;
@property (readonly, weak, nonatomic) UIButton *jumpToPageButton;
@property (readonly, weak, nonatomic) UISegmentedControl *actionsFontSizeControl;

@end
