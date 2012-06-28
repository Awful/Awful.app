//
//  AwfulForumCell.m
//  Awful
//
//  Created by me on 6/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"

@implementation AwfulForumCell
@synthesize forum = _forum;

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulParentForumCell"];
    if (self) {
        
    }
    return self;
}


-(void) setForum:(AwfulForum *)forum {
    self.textLabel.text = forum.name;
    self.textLabel.numberOfLines = 2;
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.detailTextLabel.text = forum.desc;
    self.detailTextLabel.numberOfLines = 0;
    self.detailTextLabel.font = [UIFont systemFontOfSize:12];
}

-(void) toggleFavorite:(UIButton*)button {
    button.selected = !button.selected;
    
    //get forum for that button's cell
    //set or remove favorite
    //button.state = UIControlStateNormal? UIControlStateSelected : UIControlStateNormal;
    //UIImageView* imageView = tap.view;
    
    //imageView.image = [UIImage imageNamed:@"star_on.png"];
}
@end
