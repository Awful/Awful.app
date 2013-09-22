//  AwfulLeperCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulLeperCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (readonly, nonatomic) UILabel *usernameLabel;
@property (readonly, nonatomic) UILabel *dateAndModLabel;
@property (readonly, weak, nonatomic) UILabel *reasonLabel;

+ (CGFloat)rowHeightWithBanReason:(NSString *)banReason width:(CGFloat)width;

@end
