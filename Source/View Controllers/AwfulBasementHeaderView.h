//  AwfulBasementHeaderView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulBasementHeaderView : UIView

@property (readonly, strong, nonatomic) UIImageView *avatarImageView;

@property (readonly, strong, nonatomic) UILabel *usernameLabel;

@property (assign, nonatomic) CGFloat bottomOffset;

@end
