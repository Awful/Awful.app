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
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulForumCell"];
    if (self) {
        
    }
    return self;
}


-(void) setForum:(AwfulForum *)forum {
    _forum = forum;
    self.textLabel.text = forum.name;
    self.textLabel.numberOfLines = 2;
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.detailTextLabel.text = forum.desc;
    self.detailTextLabel.numberOfLines = 0;
    self.detailTextLabel.font = [UIFont systemFontOfSize:12];
}

-(void) setFavoriteButtonAccessory {
    UIButton *favImage = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [favImage setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
    [favImage setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateSelected];
    
    [favImage addTarget:self
                 action:@selector(toggleFavorite:) 
       forControlEvents:UIControlEventTouchUpInside
     ];
    
    [favImage sizeToFit];
    favImage.selected = (self.forum.favorite != nil);
    
    self.accessoryView = favImage;
}

-(void) toggleFavorite:(UIButton*)button {
    button.selected = !button.selected;
    
    if (self.forum.favorite)
        [ApplicationDelegate.managedObjectContext deleteObject:self.forum.favorite];
    else {
        AwfulFavorite *fav = [AwfulFavorite new];
        fav.displayOrderValue = self.forum.indexValue;
        fav.forum = self.forum;
    }
    
    [ApplicationDelegate saveContext];

}


+(CGFloat) heightForContent:(AwfulForum*)forum inTableView:(UITableView*)tableView {
    int width = tableView.frame.size.width - 40;
    
    CGSize textSize = {0, 0};
    CGSize detailSize = {0, 0};
    int height = 44;
    
    textSize = [forum.name sizeWithFont:[UIFont boldSystemFontOfSize:18]
                      constrainedToSize:CGSizeMake(width, 4000) 
                          lineBreakMode:UILineBreakModeWordWrap];
    if(forum.desc)
        detailSize = [forum.desc sizeWithFont:[UIFont systemFontOfSize:12] 
                            constrainedToSize:CGSizeMake(width, 4000) 
                                lineBreakMode:UILineBreakModeWordWrap];
    
    height = 10 + textSize.height + detailSize.height;
    
    return (MAX(height,50));
}
@end
