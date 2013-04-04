//
//  AwfulPageBottomBar.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@interface AwfulPageBottomBar : UIView

@property (readonly, weak, nonatomic) UISegmentedControl *backForwardControl;
@property (readonly, weak, nonatomic) UIButton *jumpToPageButton;
@property (readonly, weak, nonatomic) UISegmentedControl *actionsFontSizeControl;

@end
