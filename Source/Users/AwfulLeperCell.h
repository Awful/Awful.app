//
//  AwfulLeperCell.h
//  Awful
//
//  Created by me on 2/1/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
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
