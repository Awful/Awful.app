//
//  AwfulLeperCell.h
//  Awful
//
//  Created by me on 2/1/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulModels.h"

@interface AwfulLeperCell : UITableViewCell

@property (nonatomic) AwfulLeper* leper;


+ (CGFloat)heightWithLeper:(AwfulLeper*)leper inTableView:(UITableView*)tableView;
@end