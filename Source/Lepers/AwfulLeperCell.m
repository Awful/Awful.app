//
//  AwfulLeperCell.m
//  Awful
//
//  Created by me on 2/1/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLeperCell.h"

@implementation AwfulLeperCell

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[[self class] description]];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setLeper:(AwfulLeper *)leper {
    self.textLabel.text = leper.jerk.username;
    self.textLabel.numberOfLines = 0;
    
    self.detailTextLabel.text = leper.reason;
    self.detailTextLabel.numberOfLines = 0;
    
    if (leper.postID)
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    UIImage *tag = [UIImage imageWithData:[NSData dataWithContentsOfFile:
                                           [[NSBundle mainBundle] pathForResource:@"icon23-banme" ofType:@"png"]]
                                    scale:2];
    self.imageView.image = tag;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    //todo: add label for mod, admin, date
    //image for ban type
}

+ (CGFloat)heightWithLeper:(AwfulLeper*)leper inTableView:(UITableView*)tableView
{
    int width = tableView.frame.size.width - 45 - 20;
    
    //shrink width if accessory present
    if (leper.postID) width -= 35;
    
    CGSize textSize = {0, 0};
    CGSize detailSize = {0, 0};
    int height = 44;
    
    if(leper.jerk.username)
        textSize = [leper.jerk.username sizeWithFont:[UIFont boldSystemFontOfSize:17]
                                   constrainedToSize:CGSizeMake(width, 4000)
                                       lineBreakMode:UILineBreakModeWordWrap];
    if(leper.reason)
        detailSize = [leper.reason sizeWithFont:[UIFont systemFontOfSize:15]
                              constrainedToSize:CGSizeMake(width, 4000)
                                  lineBreakMode:UILineBreakModeWordWrap];
    
    height = 10 + textSize.height + detailSize.height;
    
    return (height < 70 ? 70 : height);
}

@end
