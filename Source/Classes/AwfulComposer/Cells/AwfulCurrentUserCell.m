//
//  AwfulCurrentUserCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCurrentUserCell.h"
#import "AwfulUser+AwfulMethods.h"

@implementation AwfulCurrentUserCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    self.textLabel.text = @"Logged In As:";
    self.detailTextLabel.text = [[AwfulUser currentUser] userName];
    self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    return self;
}

@end
