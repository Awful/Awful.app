//
//  AwfulLeperCell.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulDisclosureIndicatorView.h"

@interface AwfulLeperCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (readonly, nonatomic) UILabel *usernameLabel;
@property (readonly, nonatomic) UILabel *dateAndModLabel;
@property (readonly, weak, nonatomic) UILabel *reasonLabel;
@property (nonatomic) AwfulDisclosureIndicatorView *disclosureIndicator;

+ (CGFloat)rowHeightWithBanReason:(NSString *)banReason width:(CGFloat)width;

@end
