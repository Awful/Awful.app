//  AwfulBadgeView.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulBadgeView : UIView

// Designated initializer.
- (id)initWithCell:(UITableViewCell *)cell;

@property (copy, nonatomic) NSString *badgeText;

@property (nonatomic) UIColor *textColor;

@property (nonatomic) UIColor *highlightedTextColor;

@property (nonatomic) UIColor *badgeColor;

@property (nonatomic) UIColor *highlightedBadgeColor;

@property (nonatomic) UIColor *offBadgeColor;

@property (getter=isOn, nonatomic) BOOL on;

@end
