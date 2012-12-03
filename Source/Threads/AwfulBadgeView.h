//
//  AwfulBadgeView.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-02.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulBadgeView : UIView

// Designated initializer.
- (id)initWithCell:(UITableViewCell *)cell;

@property (copy, nonatomic) NSString *badgeText;

@property (nonatomic) UIColor *textColor;

@property (nonatomic) UIColor *badgeColor;

@property (nonatomic) UIColor *highlightedBadgeColor;

@property (nonatomic) UIColor *offBadgeColor;

@property (getter=isOn, nonatomic) BOOL on;

@end
