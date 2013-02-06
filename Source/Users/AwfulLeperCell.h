//
//  AwfulLeperCell.h
//  Awful
//
//  Created by me on 2/1/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulParsing.h"

@interface AwfulLeperCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

+ (CGFloat)heightWithBan:(BanParsedInfo *)ban inTableView:(UITableView*)tableView;

@end
