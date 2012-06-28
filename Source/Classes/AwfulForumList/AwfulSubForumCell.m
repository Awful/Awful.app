//
//  AwfulSubForumCell.m
//  Awful
//
//  Created by me on 6/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSubForumCell.h"

@implementation AwfulSubForumCell
@synthesize forum = _forum;

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulSubForumCell"];
    if (self) {
        
    }
    return self;
}

-(void) setForum:(AwfulForum *)forum {
    self.textLabel.text = forum.name;
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.detailTextLabel.text = forum.desc;
    self.detailTextLabel.numberOfLines = 0;
    self.indentationLevel = 1;
    self.indentationWidth = 60;
    self.textLabel.font = [UIFont boldSystemFontOfSize:15];
    self.detailTextLabel.font = [UIFont boldSystemFontOfSize:14];
    
}



@end
