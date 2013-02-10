//
//  AwfulLeperCell.m
//  Awful
//
//  Created by me on 2/1/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLeperCell.h"

@implementation AwfulLeperCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    //todo: add label for mod, admin, date
    //image for ban type
}

+ (CGFloat)heightWithBan:(BanParsedInfo *)ban inTableView:(UITableView*)tableView
{
    CGFloat width = tableView.frame.size.width - 45 - 20;
    
    // shrink width if accessory present
    if (ban.postID && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) width -= 35;
    
    CGSize textSize = CGSizeZero;
    if (ban.bannedUserName) {
        textSize = [ban.bannedUserName sizeWithFont:[UIFont boldSystemFontOfSize:17]
                                  constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
                                      lineBreakMode:UILineBreakModeWordWrap];
    }
    
    CGSize detailSize = CGSizeZero;
    if (ban.banReason) {
        detailSize = [ban.banReason sizeWithFont:[UIFont systemFontOfSize:15]
                               constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
                                   lineBreakMode:UILineBreakModeWordWrap];
    }
    
    CGFloat height = 14 + textSize.height + detailSize.height;
    
    return (height < 70 ? 70 : height);
}

@end
