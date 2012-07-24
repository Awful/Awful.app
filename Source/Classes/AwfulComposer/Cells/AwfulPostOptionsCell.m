//
//  AwfulPostOptionsCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostOptionsCell.h"

@implementation AwfulPostOptionsCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Options:";
        self.detailTextLabel.text = @"Parse Urls/Show Smileys/Add Bookmark/Show Signature";
    }
    return self;
}
@end
