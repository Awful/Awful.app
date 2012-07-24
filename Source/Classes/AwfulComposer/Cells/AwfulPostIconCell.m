//
//  AwfulPostIconCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostIconCell.h"

@implementation AwfulPostIconCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Post Icon:";
        self.detailTextLabel.text = @"None";
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}
@end
