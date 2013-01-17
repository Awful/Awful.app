//
//  AwfulPrivateMessageContentCell.m
//  Awful
//
//  Created by me on 1/17/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageContentCell.h"

@implementation AwfulPrivateMessageContentCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor magentaColor];
        self.contentView.autoresizesSubviews = YES;
        self.clipsToBounds = YES;
        _messageContentView = [AwfulPostsView new];
        _messageContentView.backgroundColor = [UIColor grayColor];
    }
    return self;
}

- (void)layoutSubviews
{
    if (self.messageContentView.superview == nil) {
        [self.contentView addSubview:self.messageContentView];
    }
    
    self.messageContentView.frame = CGRectMake(20, 0, self.frame.size.width-40, self.frame.size.height);
    
    
    
}

@end
