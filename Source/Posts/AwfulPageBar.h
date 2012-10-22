//
//  AwfulPageBar.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-18.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulPageBar : UIView

@property (readonly, weak, nonatomic) UISegmentedControl *backForwardControl;

@property (readonly, weak, nonatomic) UIButton *jumpToPageButton;

@property (readonly, weak, nonatomic) UISegmentedControl *actionsComposeControl;

@end
